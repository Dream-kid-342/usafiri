import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/features/admin/repository/admin_repository.dart';
import 'package:intl/intl.dart';

final userDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, userId) async {
    final repo = ref.read(adminRepositoryProvider);
    return repo.getUserDetails(userId);
  },
);

class AdminUserDetailScreen extends ConsumerWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: const Color(0xFF2D0E0E),
        foregroundColor: Colors.white,
      ),
      body: userAsync.when(
        data: (data) {
          final profile = data['profile'];
          final payments = List<Map<String, dynamic>>.from(
            data['payments'] ?? [],
          );
          final totalSpent = data['total_spent'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(profile, totalSpent),
                const SizedBox(height: 24),
                _buildActionButtons(context, ref, profile),
                const SizedBox(height: 24),
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildPaymentHistory(payments),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> profile, dynamic totalSpent) {
    final email = profile['email'] ?? 'Unknown';
    final status = profile['subscription_status'] ?? 'Free';
    final accountStatus = profile['account_status'] ?? 'active';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                email[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              email,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  label: Text(status.toString().toUpperCase()),
                  backgroundColor: status == 'active'
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  labelStyle: TextStyle(
                    color: status == 'active' ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(accountStatus.toString().toUpperCase()),
                  backgroundColor: accountStatus == 'active'
                      ? Colors.blue.shade100
                      : Colors.red.shade100,
                  labelStyle: TextStyle(
                    color: accountStatus == 'active' ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Total Spent', 'KES $totalSpent'),
                _buildStatItem(
                  'Joined',
                  DateFormat(
                    'yMMMd',
                  ).format(DateTime.parse(profile['created_at'])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final accountStatus = profile['account_status'] ?? 'active';
    final isSuspended = accountStatus == 'suspended';

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(isSuspended ? Icons.play_arrow : Icons.block),
            label: Text(isSuspended ? 'Activate User' : 'Suspend User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuspended ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final newStatus = isSuspended ? 'active' : 'suspended';

              if (newStatus == 'suspended') {
                // Show dialog to get reason
                _showBlockReasonDialog(context, ref, userId);
              } else {
                // Activate directly
                await ref
                    .read(adminRepositoryProvider)
                    .updateUserStatus(userId, newStatus);
                ref.invalidate(userDetailsProvider(userId));
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.star),
            label: const Text('Manage Sub'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              _showSubscriptionDialog(context, ref, profile);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistory(List<Map<String, dynamic>> payments) {
    if (payments.isEmpty) return const Text('No recent activity.');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return ListTile(
          leading: const Icon(Icons.payment, color: Colors.grey),
          title: Text('Payment: KES ${payment['amount']}'),
          subtitle: Text(
            DateFormat(
              'yMMMd HH:mm',
            ).format(DateTime.parse(payment['created_at'])),
          ),
          trailing: Text(
            payment['status'].toString().toUpperCase(),
            style: TextStyle(
              color: payment['status'] == 'completed'
                  ? Colors.green
                  : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  void _showSubscriptionDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Grant PRO Access'),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              onTap: () async {
                await ref
                    .read(adminRepositoryProvider)
                    .updateUserSubscription(userId, 'active');
                ref.invalidate(userDetailsProvider(userId));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Revoke Access'),
              leading: const Icon(Icons.cancel, color: Colors.red),
              onTap: () async {
                await ref
                    .read(adminRepositoryProvider)
                    .updateUserSubscription(userId, 'base');
                ref.invalidate(userDetailsProvider(userId));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockReasonDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for suspending this user:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g. Violation of terms',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason to suspend user'),
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close dialog

              try {
                await ref
                    .read(adminRepositoryProvider)
                    .updateUserStatus(userId, 'suspended', reason: reason);

                ref.invalidate(userDetailsProvider(userId));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User suspended successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }
}
