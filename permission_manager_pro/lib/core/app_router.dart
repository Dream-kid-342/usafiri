import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:permission_manager_pro/features/auth/login_screen.dart';
import 'package:permission_manager_pro/features/auth/register_screen.dart';

import 'package:permission_manager_pro/features/client/dashboard/client_main_screen.dart';
import 'package:permission_manager_pro/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:permission_manager_pro/features/admin/dashboard/admin_user_detail_screen.dart';
import 'package:permission_manager_pro/features/auth/blocked_screen.dart';
import 'package:permission_manager_pro/features/trial/trial_expired_screen.dart';
import 'package:permission_manager_pro/features/splash/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final path = state.fullPath ?? state.uri.path;

      final isLoggingIn = path == '/login';
      final isRegistering = path == '/register';
      final isSplash = path == '/splash';
      final isRoot = path == '/';
      final isBlocked = path == '/blocked';

      // Allow splash to complete its logic
      if (isSplash) return null;

      if (session == null) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      // Check role & status
      final user = session.user;
      final metadata = user.userMetadata;
      final role = metadata?['role'] ?? 'client';
      final accountStatus = metadata?['account_status'];

      // --- ACCOUNT STATUS CHECK ---
      if (accountStatus == 'suspended' || accountStatus == 'blocked') {
        return isBlocked ? null : '/blocked';
      }

      if (isBlocked && accountStatus == 'active') {
        return role == 'admin' ? '/admin' : '/client';
      }

      // Handle root path or explicit login/register when already logged in
      if (isRoot || isLoggingIn || isRegistering) {
        return role == 'admin' ? '/admin' : '/client';
      }

      // Trial Check for Clients
      if (role == 'client' && path != '/trial-expired' && !isBlocked) {
        final trialExpiresAtStr = metadata?['trial_expires_at'];
        final subStatus = metadata?['subscription_status'] ?? 'none';

        if (subStatus != 'active' && trialExpiresAtStr != null) {
          final trialExpiresAt = DateTime.tryParse(trialExpiresAtStr);
          if (trialExpiresAt != null &&
              DateTime.now().isAfter(trialExpiresAt)) {
            return '/trial-expired';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const SplashScreen(), // Redirect will take over
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/client',

        builder: (context, state) => const ClientMainScreen(),
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) => const BlockedScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'user/:id',
            builder: (context, state) {
              final userId = state.pathParameters['id']!;
              return AdminUserDetailScreen(userId: userId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/trial-expired',
        builder: (context, state) => const TrialExpiredScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
