import '../../data/channel/permission_channel.dart';
import '../../domain/entity/app_info.dart';
import 'permission_event.dart';

enum PermissionStatus { initial, loading, loaded, error, batchProcessing }

enum ShizukuSetupStep { none, requesting, complete, denied }

class PermissionState {
  final PermissionStatus status;
  final List<AppInfo> apps;
  final DeviceCapabilities? capabilities;
  final ToggleResult? lastToggleResult;
  final String? errorMessage;
  final PermissionFilter filter;
  final String searchQuery;
  final bool showSystemApps;
  final ShizukuSetupStep shizukuSetupStep;

  const PermissionState({
    this.status = PermissionStatus.initial,
    this.apps = const [],
    this.capabilities,
    this.lastToggleResult,
    this.errorMessage,
    this.filter = PermissionFilter.all,
    this.searchQuery = '',
    this.showSystemApps = false,
    this.shizukuSetupStep = ShizukuSetupStep.none,
  });

  List<AppInfo> get filteredApps {
    var result = apps;

    // Search
    if (searchQuery.isNotEmpty) {
      result = result
          .where(
            (a) =>
                a.appName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                a.packageName.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Filter
    switch (filter) {
      case PermissionFilter.withLocation:
        result = result
            .where((a) => a.hasAnyLocation && !a.isEffectivelyBlocked)
            .toList();
        break;
      case PermissionFilter.withCamera:
        result = result.where((a) => a.hasCamera).toList();
        break;
      case PermissionFilter.withMicrophone:
        result = result.where((a) => a.hasMicrophone).toList();
        break;
      case PermissionFilter.withStorage:
        result = result.where((a) => a.hasStorage).toList();
        break;
      case PermissionFilter.background:
        result = result.where((a) => a.hasBackgroundLocation).toList();
        break;
      case PermissionFilter.activeNow:
        result = result.where((a) => a.isActiveNow).toList();
        break;
      case PermissionFilter.all:
        break;
    }

    return result;
  }

  List<AppInfo> get selectedApps => apps.where((a) => a.isSelected).toList();
  int get withLocationCount =>
      apps.where((a) => a.hasAnyLocation && !a.isEffectivelyBlocked).length;
  bool get hasSelection => apps.any((a) => a.isSelected);

  PermissionState copyWith({
    PermissionStatus? status,
    List<AppInfo>? apps,
    DeviceCapabilities? capabilities,
    ToggleResult? lastToggleResult,
    String? errorMessage,
    PermissionFilter? filter,
    String? searchQuery,
    bool? showSystemApps,
    ShizukuSetupStep? shizukuSetupStep,
  }) => PermissionState(
    status: status ?? this.status,
    apps: apps ?? this.apps,
    capabilities: capabilities ?? this.capabilities,
    lastToggleResult: lastToggleResult ?? this.lastToggleResult,
    errorMessage: errorMessage ?? errorMessage,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
    showSystemApps: showSystemApps ?? this.showSystemApps,
    shizukuSetupStep: shizukuSetupStep ?? this.shizukuSetupStep,
  );
}
