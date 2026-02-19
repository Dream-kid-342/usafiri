import 'package:flutter/material.dart';
import '../../domain/entity/app_info.dart';
import 'lazy_app_icon.dart';

class AppPermissionTile extends StatelessWidget {
  final AppInfo app;
  final Function(String permission, bool value) onToggle;
  final VoidCallback onManage;
  final bool isMultiSelectMode;
  final VoidCallback? onSelectionToggle;

  const AppPermissionTile({
    super.key,
    required this.app,
    required this.onToggle,
    required this.onManage,
    this.isMultiSelectMode = false,
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: app.isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : (isDark
                  ? theme.cardColor
                  : theme.colorScheme.surfaceVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: app.isSelected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isMultiSelectMode ? onSelectionToggle : onManage,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isMultiSelectMode) ...[
                  Checkbox(
                    value: app.isSelected,
                    onChanged: (_) => onSelectionToggle?.call(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Optimized Lazy Loading Icon
                Hero(
                  tag: 'icon_${app.packageName}',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LazyAppIcon(packageName: app.packageName, size: 40),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.packageName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.6,
                          ),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Primary Toggle Indicator
                _buildToggleSection(theme),

                const SizedBox(width: 8),

                // Action Arrow
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSection(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (app.isLoading)
          const SizedBox(
            width: 48,
            height: 24,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Switch.adaptive(
            value: app.hasAnyLocation && !app.isEffectivelyBlocked,
            onChanged: (val) => onToggle('LOCATION', val),
            activeColor: theme.colorScheme.primary,
          ),
        Text(
          'Location Access',
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
