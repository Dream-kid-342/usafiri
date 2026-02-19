import 'package:permission_manager_pro/features/payment/repository/payment_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';

part 'payment_controller.g.dart';

@riverpod
class PaymentController extends _$PaymentController {
  @override
  FutureOr<void> build() {
    // idle
  }

  Future<void> subscribe({required String phoneNumber}) async {
    state = const AsyncLoading();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      state = AsyncError('User not logged in', StackTrace.current);
      return;
    }

    state = await AsyncValue.guard(
      () => ref
          .read(paymentRepositoryProvider)
          .initiatePayment(
            phoneNumber: phoneNumber,
            amount: 1.0,
            userId: userId,
          ),
    );
  }
}
