class AppInfo {
  final String packageName;
  final String appName;
  final bool hasFineLocation;
  final bool hasCoarseLocation;
  final bool hasBackgroundLocation;
  final bool hasAnyLocation;

  // New Permissions
  final bool hasCamera;
  final bool hasMicrophone;
  final bool hasContacts;
  final bool hasPhone;
  final bool hasSms;
  final bool hasStorage;

  final int appOpsMode; // 0=allowed, 1=ignored, 3=default, 4=foreground
  final bool isSystemApp;
  final int installTime;
  final String versionName;
  final int targetSdk;
  final int? lastLocationAccessMs;
  final List<String> requestedPermissions;
  final bool isSelected; // For multi-select UI
  final bool isLoading; // Toggle in progress

  const AppInfo({
    required this.packageName,
    required this.appName,
    required this.hasFineLocation,
    required this.hasCoarseLocation,
    required this.hasBackgroundLocation,
    required this.hasAnyLocation,
    this.hasCamera = false,
    this.hasMicrophone = false,
    this.hasContacts = false,
    this.hasPhone = false,
    this.hasSms = false,
    this.hasStorage = false,
    this.appOpsMode = 3,
    required this.isSystemApp,
    required this.installTime,
    required this.versionName,
    required this.targetSdk,
    this.lastLocationAccessMs,
    this.requestedPermissions = const [],
    this.isSelected = false,
    this.isLoading = false,
  });

  bool requests(String permission) {
    final androidPerms = _mapToAndroid(permission);
    return requestedPermissions.any((p) => androidPerms.contains(p));
  }

  List<String> _mapToAndroid(String permission) {
    switch (permission.toUpperCase()) {
      case 'LOCATION':
        return [
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
          'android.permission.ACCESS_BACKGROUND_LOCATION',
        ];
      case 'CAMERA':
        return ['android.permission.CAMERA'];
      case 'MICROPHONE':
        return ['android.permission.RECORD_AUDIO'];
      case 'CONTACTS':
        return [
          'android.permission.READ_CONTACTS',
          'android.permission.WRITE_CONTACTS',
        ];
      case 'STORAGE':
        return [
          'android.permission.READ_EXTERNAL_STORAGE',
          'android.permission.WRITE_EXTERNAL_STORAGE',
          'android.permission.MANAGE_EXTERNAL_STORAGE',
        ];
      case 'PHONE':
        return [
          'android.permission.READ_PHONE_STATE',
          'android.permission.CALL_PHONE',
        ];
      case 'SMS':
        return [
          'android.permission.READ_SMS',
          'android.permission.SEND_SMS',
          'android.permission.RECEIVE_SMS',
        ];
      default:
        return [];
    }
  }

  String get lastAccessLabel {
    if (lastLocationAccessMs == null) return 'Never';
    final diff = DateTime.now().millisecondsSinceEpoch - lastLocationAccessMs!;
    if (diff < 300000) return 'Active now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    if (diff < 86400000) return '${diff ~/ 3600000}h ago';
    return '${diff ~/ 86400000}d ago';
  }

  bool get isActiveNow =>
      lastLocationAccessMs != null &&
      DateTime.now().millisecondsSinceEpoch - lastLocationAccessMs! < 300000;

  bool get isEffectivelyBlocked => appOpsMode == 1 || appOpsMode == 2;

  AppInfo copyWith({
    bool? hasFineLocation,
    bool? hasCoarseLocation,
    bool? hasBackgroundLocation,
    bool? hasAnyLocation,
    bool? hasCamera,
    bool? hasMicrophone,
    bool? hasContacts,
    bool? hasPhone,
    bool? hasSms,
    bool? hasStorage,
    int? appOpsMode,
    bool? isSelected,
    bool? isLoading,
    int? lastLocationAccessMs,
    List<String>? requestedPermissions,
  }) => AppInfo(
    packageName: packageName,
    appName: appName,
    hasFineLocation: hasFineLocation ?? this.hasFineLocation,
    hasCoarseLocation: hasCoarseLocation ?? this.hasCoarseLocation,
    hasBackgroundLocation: hasBackgroundLocation ?? this.hasBackgroundLocation,
    hasAnyLocation: hasAnyLocation ?? this.hasAnyLocation,
    hasCamera: hasCamera ?? this.hasCamera,
    hasMicrophone: hasMicrophone ?? this.hasMicrophone,
    hasContacts: hasContacts ?? this.hasContacts,
    hasPhone: hasPhone ?? this.hasPhone,
    hasSms: hasSms ?? this.hasSms,
    hasStorage: hasStorage ?? this.hasStorage,
    appOpsMode: appOpsMode ?? this.appOpsMode,
    isSystemApp: isSystemApp,
    installTime: installTime,
    versionName: versionName,
    targetSdk: targetSdk,
    lastLocationAccessMs: lastLocationAccessMs ?? this.lastLocationAccessMs,
    requestedPermissions: requestedPermissions ?? this.requestedPermissions,
    isSelected: isSelected ?? this.isSelected,
    isLoading: isLoading ?? this.isLoading,
  );
}
