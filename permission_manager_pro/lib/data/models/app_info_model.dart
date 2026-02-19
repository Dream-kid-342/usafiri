import 'dart:typed_data';

class AppInfo {
  final String name;
  final String packageName;
  final String versionName;
  final Uint8List? icon;
  final bool isSystemApp;
  bool isLocationGranted;
  bool isCameraGranted;
  bool isMicrophoneGranted;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.versionName,
    this.icon,
    this.isSystemApp = false,
    this.isLocationGranted = false,
    this.isCameraGranted = false,
    this.isMicrophoneGranted = false,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      versionName: map['versionName'] ?? '',
      isSystemApp: map['isSystemApp'] ?? false,
    );
  }
}
