import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:permission_manager_pro/features/client/provider/client_provider.dart';
import 'package:permission_manager_pro/features/payment/repository/payment_repository.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientProfile = ref.watch(clientControllerProvider);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Client Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          ),
        ],
      ),
      body: clientProfile.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found.'));
          }
          final email = profile['email'] ?? 'No Email';
          final subStatus = profile['subscription_status'] ?? 'none';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceVariant,
                  child: ListTile(
                    title: Text(
                      email,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Status: $subStatus',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                    leading: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Permissions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.camera,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Camera Access'),
                    trailing: Switch(
                      value: true,
                      onChanged: null,
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (subStatus != 'active')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showPaymentDialog(context, ref);
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Subscribe (1 KES)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();

    // Attempt auto-fill
    final user = supabase.auth.currentUser;
    if (user?.userMetadata != null && user!.userMetadata!['phone'] != null) {
      phoneController.text = user.userMetadata!['phone'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe now'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter M-Pesa Number:'),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '2547XXXXXXXX',
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
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) return;

              Navigator.pop(context);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final result = await ref
                    .read(paymentRepositoryProvider)
                    .initiatePayment(
                      phoneNumber: phone,
                      amount: 1.0, // Fixed amount for quick sub
                      userId: user!.id,
                    );

                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading

                  // Show Verification Dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      final checkoutRequestId = result['CheckoutRequestID'];
                      return StreamBuilder<String>(
                        stream: ref
                            .read(paymentRepositoryProvider)
                            .watchPaymentStatus(checkoutRequestId),
                        initialData: 'pending',
                        builder: (context, snapshot) {
                          final status = snapshot.data;

                          if (status == 'completed') {
                            return AlertDialog(
                              title: const Text('Payment Successful! ✅'),
                              content: const Text(
                                'Your subscription is now active.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ref.invalidate(clientControllerProvider);
                                  },
                                  child: const Text('Great!'),
                                ),
                              ],
                            );
                          }

                          if (status == 'failed' || status == 'cancelled') {
                            return AlertDialog(
                              title: const Text('Payment Failed ❌'),
                              content: Text(
                                'Payment was $status. Please try again.',
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
                            title: const Text('Waiting for PIN... ⏳'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Please enter your M-Pesa PIN to complete the subscription.',
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
                }
              }
            },
            child: const Text('Pay 1 KES'),
          ),
        ],
      ),
    );
  }
}
