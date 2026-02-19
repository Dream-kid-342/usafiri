import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/features/admin/provider/admin_provider.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';

class UserManagementTab extends ConsumerWidget {
  const UserManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminControllerProvider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final status = user['account_status'] ?? 'active';
            final isSuspended = status == 'suspended';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSuspended ? Colors.red : Colors.green,
                  child: Text(
                    user['email'] != null
                        ? user['email'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user['email'] ?? 'No Email'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role: ${user['role']}'),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        color: isSuspended ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'suspend') {
                      await _updateStatus(context, user['id'], 'suspended');
                    } else if (value == 'activate') {
                      await _updateStatus(context, user['id'], 'active');
                    }
                    // Refresh list
                    ref.invalidate(adminControllerProvider);
                  },
                  itemBuilder: (context) => [
                    if (!isSuspended)
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Text(
                          'Suspend User',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (isSuspended)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Text(
                          'Activate User',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String userId,
    String newStatus,
  ) async {
    try {
      // Call the Supabase function we created
      await supabase.rpc(
        'update_user_status',
        params: {'target_user_id': userId, 'new_status': newStatus},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User $newStatus successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
