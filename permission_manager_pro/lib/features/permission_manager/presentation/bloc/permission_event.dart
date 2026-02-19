abstract class PermissionEvent {}

class LoadApps extends PermissionEvent {}

class DetectCapabilities extends PermissionEvent {}

class TogglePermission extends PermissionEvent {
  final String packageName;
  final String permission; // "LOCATION", "CAMERA", etc.
  final bool allow;
  TogglePermission({
    required this.packageName,
    required this.permission,
    required this.allow,
  });
}

class BatchToggle extends PermissionEvent {
  final bool allow;
  final String permission;
  BatchToggle({required this.allow, this.permission = "LOCATION"});
}

class RefreshApp extends PermissionEvent {
  final String packageName;
  RefreshApp(this.packageName);
}

class OpenAppSettings extends PermissionEvent {
  final String packageName;
  OpenAppSettings(this.packageName);
}

class SetupShizuku extends PermissionEvent {}

class ToggleAppSelected extends PermissionEvent {
  final String packageName;
  ToggleAppSelected(this.packageName);
}

class ClearSelection extends PermissionEvent {}

class FilterChanged extends PermissionEvent {
  final PermissionFilter filter;
  FilterChanged(this.filter);
}

class SearchChanged extends PermissionEvent {
  final String query;
  SearchChanged(this.query);
}

class ShowSystemAppsChanged extends PermissionEvent {
  final bool showSystemApps;
  ShowSystemAppsChanged(this.showSystemApps);
}

enum PermissionFilter {
  all,
  withLocation,
  withCamera,
  withMicrophone,
  withStorage,
  background,
  activeNow,
}
