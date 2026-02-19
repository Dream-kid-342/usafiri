import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // 3 seconds delay as requested
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final session = supabase.auth.currentSession;
    if (session != null) {
      // User is logged in, let the router redirect logic handle it
      // We just push to a dummy route or let the auth listener kick in
      // Actually, GoRouter's redirect should handle the auth state.
      // We just need to trigger a refresh or go to home.
      // But since we are already authenticated, we might just go to '/'
      // and let the router redirect to /client or /admin
      context.go('/');
    } else {
      // New users -> Register Page as requested
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Permission Manager Pro',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
