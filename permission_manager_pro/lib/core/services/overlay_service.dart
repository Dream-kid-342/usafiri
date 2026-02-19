import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Check if the overlay permission is granted
  static Future<bool> isPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request the overlay permission
  static Future<void> requestPermission() async {
    final status = await FlutterOverlayWindow.requestPermission();
    if (status != true) {
      // Handle denial if needed
    }
  }

  /// Show the overlay
  static Future<void> showOverlay() async {
    if (await isPermissionGranted()) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Permission Manager",
        overlayContent: "Protecting you...",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.right,
        height: 150,
        width: 150,
      );
    }
  }

  /// Close the overlay
  static Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}
