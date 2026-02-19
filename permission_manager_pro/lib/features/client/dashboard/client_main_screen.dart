import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_manager_pro/features/permission_manager/presentation/bloc/permission_bloc.dart';
import 'package:permission_manager_pro/features/permission_manager/data/channel/permission_channel.dart';
import 'package:permission_manager_pro/features/client/dashboard/tabs/subscription_tab.dart';
import 'package:permission_manager_pro/features/client/dashboard/tabs/home_tab.dart';
import 'package:permission_manager_pro/features/profile/profile_screen.dart';
import 'package:permission_manager_pro/features/permission_manager/presentation/screen/permission_list_screen.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';

class ClientMainScreen extends ConsumerStatefulWidget {
  const ClientMainScreen({super.key});

  @override
  ConsumerState<ClientMainScreen> createState() => _ClientMainScreenState();
}

class _ClientMainScreenState extends ConsumerState<ClientMainScreen> {
  int _currentIndex = 0;
  StreamSubscription? _userSubscription;

  final List<Widget> _screens = [
    const HomeTab(),
    BlocProvider(
      create: (context) => PermissionBloc(channel: PermissionChannel()),
      child: const PermissionListScreen(),
    ),
    const SubscriptionTab(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Listen for changes to the user's row in public.users
    _userSubscription = supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((List<Map<String, dynamic>> data) async {
          if (data.isNotEmpty) {
            final status = data.first['account_status'];
            final trialExp = data.first['trial_expires_at'];
            final subStatus = data.first['subscription_status'];

            // 1. Kick if blocked
            if (status == 'suspended' || status == 'blocked') {
              if (mounted) {
                context.go('/blocked');
                supabase.auth.refreshSession();
              }
            }

            // 2. Force session refresh if DB status differs from metadata
            // This ensures trial_expires_at/subscription_status are synced to Auth metadata
            final metadata = supabase.auth.currentUser?.userMetadata;
            if (metadata?['trial_expires_at'] != trialExp ||
                metadata?['subscription_status'] != subStatus) {
              await supabase.auth.refreshSession();
              if (mounted)
                setState(() {}); // Rebuild to update UI based on new metadata
            }
          }
        });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata;
    final subStatus = metadata?['subscription_status'] ?? 'none';
    final trialExpiresAt = DateTime.tryParse(
      metadata?['trial_expires_at'] ?? '',
    );

    // Check if we should block the Apps tab (Index 1)
    bool splitBlock = false;
    if (subStatus != 'active') {
      // If metadata is missing but we are here, something is wrong or it's a legacy user.
      // Default to allowing IF we don't have definitive proof of expiration.
      if (trialExpiresAt != null && DateTime.now().isAfter(trialExpiresAt)) {
        splitBlock = true;
      }
    }

    final isAppsTab = _currentIndex == 1; // Apps is now index 1

    return Scaffold(
      appBar: AppBar(title: Text(_getTitle(_currentIndex))),
      body: splitBlock && isAppsTab
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Feature Locked',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Your 30-day free trial has expired. Subscribe to access App Management features.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 2; // Switch to Subscription tab
                      });
                    },
                    child: const Text('Go to Subscription'),
                  ),
                ],
              ),
            )
          : IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
          NavigationDestination(
            icon: Icon(Icons.payment),
            label: 'Subscription',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'My Apps';
      case 2:
        return 'Subscription';
      case 3:
        return 'My Profile';
      default:
        return 'Usafiri';
    }
  }
}
