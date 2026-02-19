import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool showSystemApps;
  final bool isLoading;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.showSystemApps = false, // Default to hiding system apps
    this.isLoading = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? showSystemApps,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      showSystemApps: showSystemApps ?? this.showSystemApps,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final theme = await _repository.getThemeMode();
    final showSystem = await _repository.getShowSystemApps();
    state = state.copyWith(
      themeMode: theme,
      showSystemApps: showSystem,
      isLoading: false,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    await _repository.saveThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> updateShowSystemApps(bool show) async {
    await _repository.saveShowSystemApps(show);
    state = state.copyWith(showSystemApps: show);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final repository = ref.watch(settingsRepositoryProvider);
    return SettingsNotifier(repository);
  },
);
