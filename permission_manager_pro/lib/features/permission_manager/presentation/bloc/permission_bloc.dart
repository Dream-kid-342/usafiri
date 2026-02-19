import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/channel/permission_channel.dart';
import '../../domain/entity/app_info.dart';
import 'permission_event.dart';
import 'permission_state.dart';

class PermissionBloc extends Bloc<PermissionEvent, PermissionState> {
  final PermissionChannel _channel;
  DeviceCapabilities? _caps;

  PermissionBloc({required PermissionChannel channel})
    : _channel = channel,
      super(const PermissionState()) {
    on<LoadApps>(_onLoadApps);
    on<DetectCapabilities>(_onDetectCapabilities);
    on<TogglePermission>(_onTogglePermission);
    on<BatchToggle>(_onBatchToggle);
    on<RefreshApp>(_onRefreshApp);
    on<SetupShizuku>(_onSetupShizuku);
    on<ToggleAppSelected>(_onToggleAppSelected);
    on<ClearSelection>(_onClearSelection);
    on<FilterChanged>(_onFilterChanged);
    on<SearchChanged>(_onSearchChanged);
    on<ShowSystemAppsChanged>(_onShowSystemAppsChanged);
    on<OpenAppSettings>(_onOpenAppSettings);
  }

  Future<void> _onLoadApps(
    LoadApps event,
    Emitter<PermissionState> emit,
  ) async {
    emit(state.copyWith(status: PermissionStatus.loading));
    try {
      final apps = await _channel.getInstalledApps(
        includeSystem: state.showSystemApps,
      );
      _caps ??= await _channel.detectCapabilities();
      emit(
        state.copyWith(
          status: PermissionStatus.loaded,
          apps: apps,
          capabilities: _caps,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PermissionStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDetectCapabilities(
    DetectCapabilities event,
    Emitter<PermissionState> emit,
  ) async {
    try {
      _caps = await _channel.detectCapabilities();
      emit(state.copyWith(capabilities: _caps));
    } catch (_) {}
  }

  Future<void> _onTogglePermission(
    TogglePermission event,
    Emitter<PermissionState> emit,
  ) async {
    // Optimistically update the UI state
    final appBefore = state.apps.firstWhere(
      (a) => a.packageName == event.packageName,
    );
    final optimisticApp = _applyOptimisticToggle(
      appBefore,
      event.permission,
      event.allow,
    );

    emit(
      state.copyWith(
        apps: state.apps
            .map(
              (a) => a.packageName == event.packageName
                  ? optimisticApp.copyWith(isLoading: true)
                  : a,
            )
            .toList(),
      ),
    );

    final caps = _caps ?? await _channel.detectCapabilities();
    final result = await _channel.togglePermission(
      packageName: event.packageName,
      permission: event.permission,
      allow: event.allow,
      caps: caps,
    );

    // Refresh app state - Wait significantly for system to propagate
    // Shizuku/AppOps changes can take a moment to be reflected in PackageManager/AppOpsManager checks
    await Future.delayed(const Duration(milliseconds: 800));

    final app = state.apps.firstWhere(
      (a) => a.packageName == event.packageName,
    );
    final updatedApp = await _channel.refreshApp(app);

    emit(
      state.copyWith(
        lastToggleResult: result,
        apps: state.apps
            .map(
              (a) => a.packageName == event.packageName
                  ? updatedApp.copyWith(isLoading: false)
                  : a,
            )
            .toList(),
      ),
    );
  }

  Future<void> _onBatchToggle(
    BatchToggle event,
    Emitter<PermissionState> emit,
  ) async {
    final selected = state.selectedApps;
    if (selected.isEmpty) return;

    emit(state.copyWith(status: PermissionStatus.batchProcessing));

    final caps = _caps ?? await _channel.detectCapabilities();

    for (final app in selected) {
      await _channel.togglePermission(
        packageName: app.packageName,
        permission: event.permission,
        allow: event.allow,
        caps: caps,
      );
    }

    // Refresh all apps (simpler than selective refresh in batch)
    add(LoadApps());
  }

  Future<void> _onRefreshApp(
    RefreshApp event,
    Emitter<PermissionState> emit,
  ) async {
    final index = state.apps.indexWhere(
      (a) => a.packageName == event.packageName,
    );
    if (index == -1) return;

    final updated = await _channel.refreshApp(state.apps[index]);
    emit(
      state.copyWith(
        apps: state.apps
            .map((a) => a.packageName == event.packageName ? updated : a)
            .toList(),
      ),
    );
  }

  Future<void> _onSetupShizuku(
    SetupShizuku event,
    Emitter<PermissionState> emit,
  ) async {
    emit(state.copyWith(shizukuSetupStep: ShizukuSetupStep.requesting));
    final ok = await _channel.requestShizukuPermission();
    if (ok) {
      _caps = await _channel.detectCapabilities();
      emit(
        state.copyWith(
          shizukuSetupStep: ShizukuSetupStep.complete,
          capabilities: _caps,
        ),
      );
    } else {
      emit(state.copyWith(shizukuSetupStep: ShizukuSetupStep.denied));
    }
  }

  void _onToggleAppSelected(
    ToggleAppSelected event,
    Emitter<PermissionState> emit,
  ) {
    emit(
      state.copyWith(
        apps: state.apps
            .map(
              (a) => a.packageName == event.packageName
                  ? a.copyWith(isSelected: !a.isSelected)
                  : a,
            )
            .toList(),
      ),
    );
  }

  void _onClearSelection(ClearSelection event, Emitter<PermissionState> emit) {
    emit(
      state.copyWith(
        apps: state.apps.map((a) => a.copyWith(isSelected: false)).toList(),
      ),
    );
  }

  void _onFilterChanged(FilterChanged event, Emitter<PermissionState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onSearchChanged(SearchChanged event, Emitter<PermissionState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onShowSystemAppsChanged(
    ShowSystemAppsChanged event,
    Emitter<PermissionState> emit,
  ) {
    // Update state first so LoadApps uses the new value
    emit(state.copyWith(showSystemApps: event.showSystemApps));
    add(LoadApps());
  }

  Future<void> _onOpenAppSettings(
    OpenAppSettings event,
    Emitter<PermissionState> emit,
  ) async {
    await _channel.openAppSettings(event.packageName);
  }

  AppInfo _applyOptimisticToggle(AppInfo app, String permission, bool allow) {
    switch (permission.toUpperCase()) {
      case 'LOCATION':
        return app.copyWith(hasAnyLocation: allow);
      case 'CAMERA':
        return app.copyWith(hasCamera: allow);
      case 'MICROPHONE':
        return app.copyWith(hasMicrophone: allow);
      case 'CONTACTS':
        return app.copyWith(hasContacts: allow);
      case 'STORAGE':
        return app.copyWith(hasStorage: allow);
      case 'PHONE':
        return app.copyWith(hasPhone: allow);
      case 'SMS':
        return app.copyWith(hasSms: allow);
      default:
        return app;
    }
  }
}
