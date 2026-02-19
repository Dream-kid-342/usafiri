import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../domain/entity/app_info.dart';

class PermissionChannel {
  static const _direct = MethodChannel('com.permguard.app/direct_permissions');
  static const _shizuku = MethodChannel('com.permguard.app/shizuku');

  // ─── Capabilities Detection ──────────────────────────────────────────────

  Future<DeviceCapabilities> detectCapabilities() async {
    final raw = await _direct.invokeMethod<Map>('detectCapabilities');
    final map = Map<String, dynamic>.from(raw ?? {});

    final shizukuInstalled = await _safeCall<bool>(
      () => _shizuku.invokeMethod('isShizukuInstalled'),
      false,
    );
    final shizukuRunning = shizukuInstalled
        ? await _safeCall<bool>(
            () => _shizuku.invokeMethod('isShizukuRunning'),
            false,
          )
        : false;
    final shizukuPermission = shizukuRunning
        ? await _safeCall<bool>(
            () => _shizuku.invokeMethod('hasShizukuPermission'),
            false,
          )
        : false;

    return DeviceCapabilities(
      appOpsAvailable: map['appOpsAvailable'] as bool? ?? false,
      deviceAdminActive: map['deviceAdminActive'] as bool? ?? false,
      shizukuInstalled: shizukuInstalled,
      shizukuRunning: shizukuRunning,
      shizukuPermissionGranted: shizukuPermission,
      androidVersion: map['androidVersion'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? '',
    );
  }

  // ─── App Scanning ─────────────────────────────────────────────────────────

  Future<List<AppInfo>> getInstalledApps({bool includeSystem = false}) async {
    final raw = await _direct.invokeMethod<List>('getInstalledApps', {
      'includeSystemApps': includeSystem,
    });

    return (raw ?? []).map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return _mapToAppInfo(m);
    }).toList();
  }

  Future<AppInfo> refreshApp(AppInfo app) async {
    final raw = await _direct.invokeMethod<Map>('getPermissionState', {
      'packageName': app.packageName,
    });
    final m = Map<String, dynamic>.from(raw ?? {});
    return app.copyWith(
      hasFineLocation: m['hasFineLocation'] as bool?,
      hasCoarseLocation: m['hasCoarseLocation'] as bool?,
      hasBackgroundLocation: m['hasBackgroundLocation'] as bool?,
      hasAnyLocation: m['hasAnyLocation'] as bool?,
      hasCamera: m['hasCamera'] as bool?,
      hasMicrophone: m['hasMicrophone'] as bool?,
      hasContacts: m['hasContacts'] as bool?,
      hasPhone: m['hasPhone'] as bool?,
      hasSms: m['hasSms'] as bool?,
      hasStorage: m['hasStorage'] as bool?,
      appOpsMode: m['appOpsMode'] as int?,
      requestedPermissions: (m['requestedPermissions'] as List?)
          ?.cast<String>(),
    );
  }

  AppInfo _mapToAppInfo(Map<String, dynamic> m) {
    return AppInfo(
      packageName: m['packageName'] as String,
      appName: m['appName'] as String? ?? m['packageName'] as String,
      hasFineLocation: m['hasFineLocation'] as bool? ?? false,
      hasCoarseLocation: m['hasCoarseLocation'] as bool? ?? false,
      hasBackgroundLocation: m['hasBackgroundLocation'] as bool? ?? false,
      hasAnyLocation: m['hasAnyLocation'] as bool? ?? false,
      hasCamera: m['hasCamera'] as bool? ?? false,
      hasMicrophone: m['hasMicrophone'] as bool? ?? false,
      hasContacts: m['hasContacts'] as bool? ?? false,
      hasPhone: m['hasPhone'] as bool? ?? false,
      hasSms: m['hasSms'] as bool? ?? false,
      hasStorage: m['hasStorage'] as bool? ?? false,
      appOpsMode: m['appOpsMode'] as int? ?? 3,
      isSystemApp: m['isSystemApp'] as bool? ?? false,
      installTime: (m['installTime'] as num?)?.toInt() ?? 0,
      versionName: m['versionName'] as String? ?? '',
      targetSdk: (m['targetSdk'] as num?)?.toInt() ?? 0,
      requestedPermissions:
          (m['requestedPermissions'] as List?)?.cast<String>() ?? [],
    );
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final bytes = await _direct.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      return bytes;
    } catch (e) {
      return null;
    }
  }

  // ─── Permission Toggling — Core Logic ────────────────────────────────────

  Future<ToggleResult> togglePermission({
    required String packageName,
    required String permission, // "LOCATION", "CAMERA", etc.
    required bool allow,
    required DeviceCapabilities caps,
  }) async {
    if (caps.shizukuPermissionGranted) {
      final shizukuResult = await _toggleViaShizuku(
        packageName: packageName,
        permission: permission,
        allow: allow,
      );
      if (shizukuResult.success) return shizukuResult;
    }

    final nativeResult = await _toggleViaNative(
      packageName: packageName,
      permission: permission,
      allow: allow,
    );

    if (nativeResult.success) return nativeResult;

    return ToggleResult(
      success: false,
      method: ToggleMethod.fallback,
      message: 'Direct control unavailable — opening system settings',
      requiresFallback: true,
    );
  }

  Future<ToggleResult> _toggleViaNative({
    required String packageName,
    required String permission,
    required bool allow,
  }) async {
    try {
      final raw = await _direct.invokeMethod<Map>('togglePermission', {
        'packageName': packageName,
        'permission': permission,
        'allow': allow,
      });
      final map = Map<String, dynamic>.from(raw ?? {});
      final success = map['success'] as bool? ?? false;
      return ToggleResult(
        success: success,
        method: ToggleMethod.appOps,
        message: success ? 'Permission updated' : 'Failed to update',
      );
    } catch (e) {
      return ToggleResult(
        success: false,
        method: ToggleMethod.appOps,
        message: e.toString(),
      );
    }
  }

  Future<ToggleResult> _toggleViaShizuku({
    required String packageName,
    required String permission,
    required bool allow,
  }) async {
    try {
      final permissions = _mapToAndroidPermissions(permission);
      if (permissions.isEmpty) {
        return ToggleResult(
          success: false,
          method: ToggleMethod.shizuku,
          message: 'Unknown permission: $permission',
        );
      }

      bool allOk = true;
      for (final perm in permissions) {
        final raw = await _shizuku.invokeMethod<Map>(
          allow ? 'grantPermission' : 'revokePermission',
          {'packageName': packageName, 'permission': perm},
        );
        final result = Map<String, dynamic>.from(raw ?? {});
        if (result['success'] != true) allOk = false;
      }

      return ToggleResult(
        success: allOk,
        method: ToggleMethod.shizuku,
        message: allOk ? '$permission updated' : 'Some updates failed',
      );
    } catch (e) {
      return ToggleResult(
        success: false,
        method: ToggleMethod.shizuku,
        message: e.toString(),
      );
    }
  }

  List<String> _mapToAndroidPermissions(String permission) {
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
          // MANAGE_EXTERNAL_STORAGE is an AppOp primarily, but pm grant might work on some
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

  // ─── Shizuku Setup ────────────────────────────────────────────────────────

  Future<bool> requestShizukuPermission() async {
    return _safeCall<bool>(
      () => _shizuku.invokeMethod('requestShizukuPermission'),
      false,
    );
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  Future<void> openAppSettings(String packageName) async {
    await _direct.invokeMethod('openAppSettings', {'packageName': packageName});
  }

  Future<void> openUsageAccessSettings() async {
    await _direct.invokeMethod('openUsageAccessSettings');
  }

  Future<bool> hasUsageAccess() async {
    return _safeCall<bool>(() => _direct.invokeMethod('hasUsageAccess'), false);
  }

  Future<T> _safeCall<T>(Future<T?> Function() fn, T fallback) async {
    try {
      return await fn() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

// ─── Result & Capability Models ──────────────────────────────────────────────

enum ToggleMethod { shizuku, appOps, deviceAdmin, fallback }

class ToggleResult {
  final bool success;
  final ToggleMethod method;
  final String message;
  final bool requiresFallback;
  final bool requiresShizuku;

  const ToggleResult({
    required this.success,
    required this.method,
    required this.message,
    this.requiresFallback = false,
    this.requiresShizuku = false,
  });
}

class DeviceCapabilities {
  final bool appOpsAvailable;
  final bool deviceAdminActive;
  final bool shizukuInstalled;
  final bool shizukuRunning;
  final bool shizukuPermissionGranted;
  final int androidVersion;
  final String manufacturer;

  const DeviceCapabilities({
    required this.appOpsAvailable,
    required this.deviceAdminActive,
    required this.shizukuInstalled,
    required this.shizukuRunning,
    required this.shizukuPermissionGranted,
    required this.androidVersion,
    required this.manufacturer,
  });

  ToggleMethod get bestMethod {
    if (shizukuPermissionGranted) return ToggleMethod.shizuku;
    if (appOpsAvailable) return ToggleMethod.appOps;
    if (deviceAdminActive) return ToggleMethod.deviceAdmin;
    return ToggleMethod.fallback;
  }

  bool get canDirectlyControl =>
      shizukuPermissionGranted || appOpsAvailable || deviceAdminActive;

  String get methodLabel {
    switch (bestMethod) {
      case ToggleMethod.shizuku:
        return 'Shizuku (Full Control)';
      case ToggleMethod.appOps:
        return 'AppOps (Direct)';
      case ToggleMethod.deviceAdmin:
        return 'Device Admin';
      case ToggleMethod.fallback:
        return 'Manual (Settings)';
    }
  }
}
