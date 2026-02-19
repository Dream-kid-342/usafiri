import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_repository.g.dart';

@riverpod
AdminRepository adminRepository(AdminRepositoryRef ref) {
  return AdminRepository(supabase);
}

class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> getStats() async {
    final totalUsers = await _client.from('users').count();
    // For now simple count, in real app we might want more complex queries
    // Supabase count() returns PostgrestResponse with count
    // But .count() is deprecated or specific syntax depending on version.
    // simpler:
    final usersResponse = await _client.from('users').count();
    final count = usersResponse;

    return {
      'totalUsers': count,
      'activeSubscriptions': 0, // Placeholder
    };
  }

  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      final response = await _client.rpc(
        'get_user_details',
        params: {'target_user_id': userId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      // Fallback if RPC fails or not deployed yet
      // Fetch manually
      final user = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      final payments = await _client
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      double totalSpent = 0;
      for (var p in payments) {
        if (p['status'] == 'completed') {
          totalSpent += (p['amount'] as num).toDouble();
        }
      }

      return {'profile': user, 'payments': payments, 'total_spent': totalSpent};
    }
  }

  Future<void> updateUserStatus(
    String userId,
    String status, {
    String? reason,
  }) async {
    await _client
        .from('users')
        .update({
          'account_status': status,
          'block_reason':
              reason, // Will be null if strictly activating, which clears it? No, keep history?
          // Actually, if activating, we might want to clear it or keep it.
          // Let's explicitly set it if provided, or clear it if status is active.
          if (status == 'active') 'block_reason': null,
          if (status != 'active' && reason != null) 'block_reason': reason,
        })
        .eq('id', userId);
  }

  Future<void> updateUserSubscription(String userId, String status) async {
    await _client
        .from('users')
        .update({'subscription_status': status})
        .eq('id', userId);
  }
}
