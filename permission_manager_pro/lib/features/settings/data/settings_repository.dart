import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsRepository {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyShowSystemApps = 'show_system_apps';

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    return ThemeMode.values[index];
  }

  Future<void> saveShowSystemApps(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowSystemApps, show);
  }

  Future<bool> getShowSystemApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowSystemApps) ?? false;
  }
}
