import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/features/home/home_controller.dart';
import 'package:installed_apps/installed_apps.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsState = ref.watch(homeControllerProvider);

    return Scaffold(
      // We might want to keep Scaffold body only or remove Scaffold if parent handles it.
      // Actually, keeping Scaffold is fine for body, but we should remove AppBar as parent has it.
      // Or we can keep it if we want distinct app bars.
      // The ClientMainScreen has an AppBar. So HomeScreen should probably just be the list.
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(homeControllerProvider.notifier).fetchInstalledApps();
        },
        child: appsState.when(
          data: (apps) {
            if (apps.isEmpty) {
              return const Center(child: Text('No apps found'));
            }
            return ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return ListTile(
                  leading: app.icon != null
                      ? Image.memory(app.icon!, width: 40, height: 40)
                      : const Icon(Icons.android),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  trailing: TextButton(
                    onPressed: () {
                      InstalledApps.openSettings(app.packageName);
                    },
                    child: const Text('Manage'),
                  ),
                );
              },
            );
          },
          error: (err, stack) => Center(child: Text('Error: $err')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
