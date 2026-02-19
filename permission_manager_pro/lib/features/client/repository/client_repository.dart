import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client_repository.g.dart';

@riverpod
ClientRepository clientRepository(ClientRepositoryRef ref) {
  return ClientRepository(supabase);
}

class ClientRepository {
  final SupabaseClient _client;

  ClientRepository(this._client);

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }
}
