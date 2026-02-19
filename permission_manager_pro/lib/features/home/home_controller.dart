import 'package:installed_apps/installed_apps.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/data/models/app_info_model.dart';

final homeControllerProvider =
    StateNotifierProvider<HomeController, AsyncValue<List<AppInfo>>>((ref) {
      return HomeController();
    });

class HomeController extends StateNotifier<AsyncValue<List<AppInfo>>> {
  HomeController() : super(const AsyncLoading()) {
    fetchInstalledApps();
  }

  Future<void> fetchInstalledApps() async {
    try {
      state = const AsyncLoading();
      // Fetch installed apps
      final apps = await InstalledApps.getInstalledApps(true, true);

      final appInfos = apps.map((app) {
        return AppInfo(
          name: app.name,
          packageName: app.packageName,
          versionName: app.versionName,
          icon: app.icon,
          isSystemApp: false,
        );
      }).toList();

      state = AsyncData(appInfos);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
