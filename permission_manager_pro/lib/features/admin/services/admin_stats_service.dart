import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final service = AdminStatsService();
  return service.fetchStats();
});

class AdminStats {
  final int totalUsers;
  final int activeSubscriptions;
  final double totalRevenue;
  final List<int> weeklyActivity;

  AdminStats({
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.totalRevenue,
    required this.weeklyActivity,
  });
}

class AdminStatsService {
  Future<AdminStats> fetchStats() async {
    try {
      // 1. Total Users
      final usersResponse = await supabase
          .from('users')
          .select('id, subscription_status');
      final users = usersResponse as List<dynamic>;
      final totalUsers = users.length;

      // 2. Active Subscriptions
      final activeUsers = users
          .where((u) => u['subscription_status'] == 'active')
          .length;

      // 3. Payments (Revenue & Weekly Activity)
      final paymentsResponse = await supabase
          .from('payments')
          .select('amount, status, created_at')
          .order('created_at', ascending: false);
      final payments = paymentsResponse as List<dynamic>;

      double totalRevenue = 0;
      List<int> weeklyActivity = List.filled(7, 0);
      final now = DateTime.now();

      for (var p in payments) {
        if (p['status'] == 'completed') {
          // Revenue
          final amount = p['amount'];
          double val = 0;
          if (amount is num) {
            val = amount.toDouble();
          } else if (amount is String) {
            val = double.tryParse(amount) ?? 0.0;
          }
          totalRevenue += val;

          // Weekly Activity
          if (p['created_at'] != null) {
            final created = DateTime.parse(p['created_at']);
            final diff = now.difference(created).inDays;

            // Index 6 is Today. Index 0 is 6 days ago.
            if (diff >= 0 && diff < 7) {
              int index = 6 - diff;
              weeklyActivity[index] += val.toInt();
            }
          }
        }
      }

      return AdminStats(
        totalUsers: totalUsers,
        activeSubscriptions: activeUsers,
        totalRevenue: totalRevenue,
        weeklyActivity: weeklyActivity,
      );
    } catch (e) {
      print('Error fetching admin stats: $e');
      return AdminStats(
        totalUsers: 0,
        activeSubscriptions: 0,
        totalRevenue: 0.0,
        weeklyActivity: [0, 0, 0, 0, 0, 0, 0],
      );
    }
  }
}
