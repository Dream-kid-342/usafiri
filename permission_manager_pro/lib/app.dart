import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/core/app_router.dart';
import 'package:permission_manager_pro/core/theme.dart';

import 'package:permission_manager_pro/features/settings/provider/settings_provider.dart';
import 'package:permission_manager_pro/core/services/overlay_service.dart';

class PermissionManagerApp extends ConsumerStatefulWidget {
  const PermissionManagerApp({super.key});

  @override
  ConsumerState<PermissionManagerApp> createState() =>
      _PermissionManagerAppState();
}

class _PermissionManagerAppState extends ConsumerState<PermissionManagerApp> {
  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
  }

  Future<void> _checkOverlayPermission() async {
    // Check and request overlay permission on startup if needed
    // This is a gentle check, we might want to be more aggressive based on requirements
    if (!await OverlayService.isPermissionGranted()) {
      // Create a logical place to ask for this, maybe a dialog
      // For now, we'll let the user initiate it or do it here
      // await OverlayService.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);

    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Usafiri',
      theme: AppTheme.lightTheme, // Ensure light theme is available
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
