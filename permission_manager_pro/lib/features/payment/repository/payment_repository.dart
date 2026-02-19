import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_manager_pro/core/app_config.dart';

part 'payment_repository.g.dart';

@riverpod
PaymentRepository paymentRepository(PaymentRepositoryRef ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  return PaymentRepository(supabase, dio);
}

class PaymentRepository {
  final SupabaseClient _supabase;
  final Dio _dio;

  // Simple in-memory cache for the access token
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  PaymentRepository(this._supabase, this._dio);

  Future<String> _getAccessToken() async {
    // Return cached token if still valid (Safaricom tokens last 3599s, we use 50m for safety)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    final consumerKey = AppConfig.mpesaConsumerKey;
    final consumerSecret = AppConfig.mpesaConsumerSecret;
    final auth = base64.encode(utf8.encode('$consumerKey:$consumerSecret'));

    final url = AppConfig.isSandbox
        ? 'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials'
        : 'https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials';

    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {'Authorization': 'Basic $auth'}),
      );

      if (response.statusCode == 200) {
        _cachedToken = response.data['access_token'];
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
        return _cachedToken!;
      } else {
        throw Exception('Failed to generate M-Pesa token: ${response.data}');
      }
    } catch (e) {
      print('M-Pesa Auth Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required double amount,
    required String userId,
    String? planId,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final shortcode = AppConfig.mpesaShortcode;
      final passkey = AppConfig.mpesaPasskey;

      final password = base64.encode(
        utf8.encode('$shortcode$passkey$timestamp'),
      );

      final url = AppConfig.isSandbox
          ? 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
          : 'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest';

      // Format phone: 07xx -> 2547xx, +254 -> 254
      String formattedPhone = phoneNumber
          .replaceAll('+', '')
          .replaceAll(' ', '');
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '254${formattedPhone.substring(1)}';
      }

      final body = {
        "BusinessShortCode": shortcode,
        "Password": password,
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": amount.toInt(),
        "PartyA": formattedPhone,
        "PartyB": shortcode,
        "PhoneNumber": formattedPhone,
        "CallBackURL": AppConfig.mpesaCallbackUrl,
        "AccountReference": "PM_PRO_${userId.substring(0, 5)}",
        "TransactionDesc": "Payment for Permission Manager Pro",
      };

      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['ResponseCode'] == "0") {
        final stkData = response.data;
        final checkoutRequestId = stkData['CheckoutRequestID'];

        print('M-Pesa STK Push Initialized: $checkoutRequestId');
        print('Attempting to save pending record for User: $userId');

        try {
          // Log to Supabase for persistence
          final insertResponse = await _supabase
              .from('payments')
              .insert({
                'user_id': userId,
                'phone': formattedPhone,
                'amount': amount,
                'checkout_request_id': checkoutRequestId,
                'merchant_request_id': stkData['MerchantRequestID'],
                'status': 'pending',
              })
              .select()
              .single();

          print(
            'SUCCESS: M-Pesa Payment Record Saved: ${insertResponse['id']}',
          );
        } catch (dbError) {
          print('DATABASE ERROR saving payment record: $dbError');
          // We still return stkData so the user sees the prompt,
          // but we know why the callback will fail later.
        }

        return stkData;
      } else {
        throw Exception('M-Pesa STK Push Failed: ${response.data}');
      }
    } catch (e, stack) {
      // Log error to Supabase for Admin review
      try {
        await _supabase.from('error_logs').insert({
          'user_id': userId,
          'error_message': e.toString(),
          'stack_trace': stack.toString(),
          'context': 'PaymentRepository.initiatePayment',
        });
      } catch (logError) {
        print('Failed to log error to Supabase: $logError');
      }

      print('Payment Error details: $e');
      rethrow;
    }
  }

  /// Polls the payment status from Supabase
  Future<String> checkPaymentStatus(String checkoutRequestId) async {
    final response = await _supabase
        .from('payments')
        .select('status')
        .eq('checkout_request_id', checkoutRequestId)
        .single();

    return response['status'] ?? 'pending';
  }

  /// Returns a stream of status updates for a specific payment
  Stream<String> watchPaymentStatus(String checkoutRequestId) {
    return _supabase
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('checkout_request_id', checkoutRequestId)
        .map(
          (event) =>
              event.isEmpty ? 'pending' : (event.first['status'] ?? 'pending'),
        );
  }
}
