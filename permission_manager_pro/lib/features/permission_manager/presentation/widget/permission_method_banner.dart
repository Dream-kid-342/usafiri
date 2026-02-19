import 'package:flutter/material.dart';
import '../../data/channel/permission_channel.dart';

class PermissionMethodBanner extends StatelessWidget {
  final DeviceCapabilities capabilities;
  final VoidCallback onSetupShizuku;

  const PermissionMethodBanner({
    super.key,
    required this.capabilities,
    required this.onSetupShizuku,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (capabilities.shizukuPermissionGranted) {
      return _buildBanner(
        theme: theme,
        icon: Icons.flash_on_rounded,
        label: 'Full Control via Shizuku',
        sublabel: 'Permissions change instantly',
        color: const Color(0xFF22C55E),
        bgColor: const Color(0xFF22C55E).withOpacity(0.1),
      );
    }

    if (capabilities.appOpsAvailable) {
      return _buildBanner(
        theme: theme,
        icon: Icons.tune_rounded,
        label: 'Direct Control via AppOps',
        sublabel: 'Changes apply immediately',
        color: theme.colorScheme.primary,
        bgColor: theme.colorScheme.primary.withOpacity(0.1),
      );
    }

    if (capabilities.shizukuInstalled && !capabilities.shizukuRunning) {
      return _buildBanner(
        theme: theme,
        icon: Icons.info_outline_rounded,
        label: 'Shizuku found but not running',
        sublabel: 'Tap to enable full control',
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFF59E0B).withOpacity(0.1),
        action: TextButton(
          onPressed: onSetupShizuku,
          child: const Text(
            'Enable',
            style: TextStyle(color: Color(0xFFF59E0B)),
          ),
        ),
      );
    }

    return _buildBanner(
      theme: theme,
      icon: Icons.settings_rounded,
      label: 'Enable Shizuku for direct control',
      sublabel: 'Currently opening settings to change each app',
      color: theme.colorScheme.onSurface.withOpacity(0.4),
      bgColor: theme.colorScheme.surfaceVariant,
      action: TextButton(
        onPressed: onSetupShizuku,
        child: Text(
          'Setup',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildBanner({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color bgColor,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}
