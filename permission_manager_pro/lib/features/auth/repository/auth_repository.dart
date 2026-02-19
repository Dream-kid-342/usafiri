import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(supabase.auth);
}

class AuthRepository {
  final GoTrueClient _auth;

  AuthRepository(this._auth);

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String phone,
  }) async {
    final trialExpiresAt = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String();

    return _auth.signUp(
      email: email,
      password: password,
      data: {
        'phone': phone,
        'subscription_status': 'trial',
        'trial_expires_at': trialExpiresAt,
        'role': 'client', // Explicitly set role
        'account_status': 'active', // Default to active
      },
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // In a real scenario, we might want to fetch this from the 'public.users' table
    // to be 100% sure, as metadata can be stale if not updated on the client.
    // But for now, let's check metadata first.
    return user.userMetadata?['role'] as String?;
  }
}
