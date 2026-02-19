import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entity/app_info.dart';
import '../bloc/permission_bloc.dart';
import '../bloc/permission_event.dart';
import '../bloc/permission_state.dart';
import '../widget/lazy_app_icon.dart';

class AppDetailsScreen extends StatelessWidget {
  final String packageName;

  const AppDetailsScreen({super.key, required this.packageName});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PermissionBloc, PermissionState>(
      builder: (context, state) {
        final app = state.apps.firstWhere(
          (a) => a.packageName == packageName,
          orElse: () => AppInfo(
            packageName: packageName,
            appName: 'Unknown',
            hasFineLocation: false,
            hasCoarseLocation: false,
            hasBackgroundLocation: false,
            hasAnyLocation: false,
            hasCamera: false,
            hasMicrophone: false,
            hasContacts: false,
            hasPhone: false,
            hasSms: false,
            hasStorage: false,
            isSystemApp: false,
            installTime: 0,
            versionName: '',
            targetSdk: 0,
          ),
        );

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage App'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<PermissionBloc>().add(RefreshApp(packageName)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header section
              Center(
                child: Column(
                  children: [
                    Hero(
                      tag: 'icon_$packageName',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(
                            0.5,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: LazyAppIcon(packageName: packageName, size: 64),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      app.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      app.packageName,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    _buildVersionBadges(app, theme),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (app.isSystemApp)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'System App: Modifying permissions may affect device stability.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildSectionTitle('Active Permission Controls', theme),
              const SizedBox(height: 8),

              if (app.requests('LOCATION'))
                _buildPermissionTile(
                  'Location',
                  Icons.location_on_outlined,
                  app.hasAnyLocation && !app.isEffectivelyBlocked,
                  (val) => _toggle(context, 'LOCATION', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('CAMERA'))
                _buildPermissionTile(
                  'Camera',
                  Icons.camera_alt_outlined,
                  app.hasCamera,
                  (val) => _toggle(context, 'CAMERA', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('MICROPHONE'))
                _buildPermissionTile(
                  'Microphone',
                  Icons.mic_none_outlined,
                  app.hasMicrophone,
                  (val) => _toggle(context, 'MICROPHONE', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('CONTACTS'))
                _buildPermissionTile(
                  'Contacts',
                  Icons.contacts_outlined,
                  app.hasContacts,
                  (val) => _toggle(context, 'CONTACTS', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('STORAGE'))
                _buildPermissionTile(
                  'Storage',
                  Icons.folder_open_outlined,
                  app.hasStorage,
                  (val) => _toggle(context, 'STORAGE', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('PHONE'))
                _buildPermissionTile(
                  'Phone',
                  Icons.phone_outlined,
                  app.hasPhone,
                  (val) => _toggle(context, 'PHONE', val),
                  theme,
                  app.isLoading,
                ),
              if (app.requests('SMS'))
                _buildPermissionTile(
                  'SMS',
                  Icons.sms_outlined,
                  app.hasSms,
                  (val) => _toggle(context, 'SMS', val),
                  theme,
                  app.isLoading,
                ),

              // If no permissions are requested
              if (![
                'LOCATION',
                'CAMERA',
                'MICROPHONE',
                'CONTACTS',
                'STORAGE',
                'PHONE',
                'SMS',
              ].any((p) => app.requests(p)))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'This app does not request any manageable runtime permissions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              _buildSectionTitle('Advanced', theme),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                leading: Icon(
                  Icons.settings_applications_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('System App Settings'),
                subtitle: const Text('Access native Android controls'),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                onTap: () => context.read<PermissionBloc>().add(
                  OpenAppSettings(packageName),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggle(BuildContext context, String permission, bool value) {
    context.read<PermissionBloc>().add(
      TogglePermission(
        packageName: packageName,
        permission: permission,
        allow: value,
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildVersionBadges(AppInfo app, ThemeData theme) {
    return Wrap(
      spacing: 8,
      children: [
        if (app.isSystemApp) _buildBadge('System', Colors.orange, theme),
        _buildBadge('SDK ${app.targetSdk}', Colors.blue, theme),
        if (app.versionName.isNotEmpty)
          _buildBadge(app.versionName, Colors.grey, theme),
      ],
    );
  }

  Widget _buildBadge(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    ThemeData theme,
    bool isLoading,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? null : theme.colorScheme.surfaceVariant.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch.adaptive(value: value, onChanged: onChanged),
      ),
    );
  }
}
