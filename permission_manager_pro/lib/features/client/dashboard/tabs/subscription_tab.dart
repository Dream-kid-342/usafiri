import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:permission_manager_pro/features/payment/repository/payment_plan_repository.dart';
import 'package:permission_manager_pro/features/payment/models/payment_plan.dart';
import 'package:permission_manager_pro/features/payment/repository/payment_repository.dart';

final activePlansProvider = FutureProvider.autoDispose<List<PaymentPlan>>((
  ref,
) async {
  return ref.read(paymentPlanRepositoryProvider).getActivePlans();
});

class SubscriptionTab extends ConsumerWidget {
  const SubscriptionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata;
    final email = user?.email ?? 'Unknown';
    final plansAsync = ref.watch(activePlansProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(email, metadata),
            const SizedBox(height: 24),
            const Text(
              'Subscription Packages',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return const Text('No active plans available.');
                }
                return Column(
                  children: plans
                      .map(
                        (plan) => _buildPackageCard(
                          context,
                          ref,
                          plan: plan,
                          isActive:
                              metadata?['plan_id'] == plan.id ||
                              (metadata?['subscription_status'] == 'active' &&
                                  plan.price > 0),
                          // Simple check, ideal world we store plan_id in user metadata
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text(
                'Error loading plans: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(String email, Map<String, dynamic>? metadata) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.indigo,
              child: Text(
                email[0].toUpperCase(),
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${metadata?['subscription_status'] ?? 'Free Trial'}',
                    style: TextStyle(
                      color: metadata?['subscription_status'] == 'active'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context,
    WidgetRef ref, {
    required PaymentPlan plan,
    required bool isActive,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? Colors.green.withOpacity(0.05) : null,
      shape: isActive
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'KES ${plan.price}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigoAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (plan.description != null) ...[
              Text(plan.description!),
              const SizedBox(height: 8),
            ],
            // Features list
            if (plan.features.isNotEmpty)
              ...plan.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? const ElevatedButton(
                      onPressed: null,
                      child: Text('Active Plan'),
                    )
                  : ElevatedButton(
                      onPressed: () => _showPaymentDialog(context, ref, plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Subscribe Now'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    PaymentPlan plan,
  ) {
    final phoneController = TextEditingController();

    // Auto-fill with user phone if available
    final user = supabase.auth.currentUser;
    if (user?.userMetadata != null && user!.userMetadata!['phone'] != null) {
      phoneController.text = user.userMetadata!['phone'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Subscribe to ${plan.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: KES ${plan.price}'),
            const SizedBox(height: 16),
            const Text('Enter M-Pesa Phone Number:'),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '2547XXXXXXXX',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (phoneController.text.isNotEmpty) {
                _initiatePayment(context, ref, phoneController.text, plan);
              }
            },
            child: const Text('Pay & Subscribe'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment(
    BuildContext context,
    WidgetRef ref,
    String phone,
    PaymentPlan plan,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ref
          .read(paymentRepositoryProvider)
          .initiatePayment(
            phoneNumber: phone,
            amount: plan.price,
            userId: user.id,
            planId: plan.id,
          );

      // Dismiss Loading Dialog
      if (context.mounted) Navigator.pop(context);

      // Show Verification Dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final checkoutRequestId = result['CheckoutRequestID'];
            return StreamBuilder<String>(
              stream: ref
                  .read(paymentRepositoryProvider)
                  .watchPaymentStatus(checkoutRequestId)
                  .timeout(
                    const Duration(seconds: 15),
                    onTimeout: (sink) {
                      sink.add('timeout');
                    },
                  ),
              initialData: 'pending',
              builder: (context, snapshot) {
                final status = snapshot.data;

                if (status == 'completed') {
                  return AlertDialog(
                    title: const Text('Payment Successful! ✅'),
                    content: const Text('Your subscription is now active.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Refresh profile or home state
                          ref.invalidate(activePlansProvider);
                        },
                        child: const Text('Great!'),
                      ),
                    ],
                  );
                }

                if (status == 'failed' ||
                    status == 'cancelled' ||
                    status == 'timeout') {
                  return AlertDialog(
                    title: const Text('Payment Error ❌'),
                    content: Text(
                      status == 'timeout'
                          ? 'Payment session timed out. It looks like the payment has not been made yet.'
                          : 'Payment was $status. Please try again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  title: const Text('Waiting for Payment... ⏳'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Please enter your M-Pesa PIN on your phone to complete the purchase.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Do not close this window until the process is finished.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel Verification'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    } catch (e) {
      // Dismiss Loading
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment Failed ❌'),
            content: Text(
              'Could not initiate payment.\n\nError: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildPaymentHistory() {
    // Placeholder (Implement logic to fetch from 'payments' table later)
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No payments found.'),
      ),
    );
  }
}
