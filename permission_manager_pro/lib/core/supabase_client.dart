import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_manager_pro/core/app_config.dart';

final supabase = Supabase.instance.client;

final supabaseUrl = AppConfig.supabaseUrl;
final supabaseAnonKey = AppConfig.supabaseAnonKey;
