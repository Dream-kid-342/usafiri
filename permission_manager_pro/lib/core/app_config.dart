import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // M-Pesa Configuration
  static String get mpesaEnvironment =>
      dotenv.env['MPESA_ENVIRONMENT'] ?? 'sandbox';
  static bool get isSandbox => mpesaEnvironment.toLowerCase() == 'sandbox';

  static const String mpesaPaymentFunction = 'mpesa-stk-push';
  static const String mpesaCallbackFunction = 'mpesa-callback';

  // Selection logic for Consumer Key
  static String get mpesaConsumerKey => isSandbox
      ? (dotenv.env['MPESA_CONSUMER_KEY_SANDBOX'] ?? '')
      : (dotenv.env['MPESA_CONSUMER_KEY_PROD'] ?? '');

  static String get mpesaConsumerSecret => isSandbox
      ? (dotenv.env['MPESA_CONSUMER_SECRET_SANDBOX'] ?? '')
      : (dotenv.env['MPESA_CONSUMER_SECRET_PROD'] ?? '');

  static String get mpesaShortcode => isSandbox
      ? (dotenv.env['MPESA_SHORTCODE_SANDBOX'] ?? '')
      : (dotenv.env['MPESA_SHORTCODE_PROD'] ?? '');

  static String get mpesaPasskey => isSandbox
      ? (dotenv.env['MPESA_PASSKEY_SANDBOX'] ?? '')
      : (dotenv.env['MPESA_PASSKEY_PROD'] ?? '');

  static String get mpesaCallbackUrl => dotenv.env['MPESA_CALLBACK_URL'] ?? '';

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }
}
