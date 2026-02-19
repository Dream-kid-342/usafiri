import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_manager_pro/core/app_config.dart';

import 'package:permission_manager_pro/features/overlay/overlay_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.load();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: PermissionManagerApp()));
}

// Overlay Entry Point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayWidget()),
  );
}
