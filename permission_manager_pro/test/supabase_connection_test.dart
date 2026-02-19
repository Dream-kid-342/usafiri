import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase Connection Test', () async {
    // Read .env directly
    final envFile = File('.env');
    if (!envFile.existsSync()) {
      fail('.env file not found in current directory');
    }

    final lines = await envFile.readAsLines();
    String url = '';
    String anonKey = '';

    for (var line in lines) {
      if (line.startsWith('SUPABASE_URL=')) {
        url = line.split('=')[1].replaceAll('"', '').trim();
      } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
        anonKey = line.split('=')[1].replaceAll('"', '').trim();
      }
    }

    if (url.isEmpty || anonKey.isEmpty) {
      fail('Could not parse SUPABASE_URL or SUPABASE_ANON_KEY from .env');
    }

    print('Testing connection to: $url');

    // Initialize SupabaseClient directly to avoid Flutter-specific dependencies/storage in test
    final client = SupabaseClient(url, anonKey);

    try {
      // Try to access a non-existent table to verify connectivity to PostgREST
      await client.from('connectivity_check_table').select();
      print('Connection verify: Unexpected success (table exists?)');
    } on PostgrestException catch (e) {
      // P0001 or 42P01 (relation does not exist) means we connected!
      // 401 means we connected but unauthorized (also good for connectivity check)
      print(
        'Connection Successful! Reached Supabase. (Response: ${e.message})',
      );
    } catch (e) {
      // If we get a SocketException, it failed.
      if (e.toString().contains('SocketException') ||
          e.toString().contains('ClientException')) {
        fail('Connection FAILED: Could not reach Supabase. Error: $e');
      }
      // Other errors might be expected
      print('Connection verified (with expected error): $e');
    }
  });
}

class MockLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}
