import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/permission_bloc.dart';
import '../bloc/permission_event.dart';
import '../bloc/permission_state.dart';
import '../widget/app_permission_tile.dart';
import '../widget/permission_method_banner.dart';
import '../widget/shizuku_setup_sheet.dart';
import 'app_details_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/settings/provider/settings_provider.dart';

class PermissionListScreen extends ConsumerStatefulWidget {
  const PermissionListScreen({super.key});
  @override
  ConsumerState<PermissionListScreen> createState() =>
      _PermissionListScreenState();
}

class _PermissionListScreenState extends ConsumerState<PermissionListScreen>
    with WidgetsBindingObserver {
  String? _pendingRefreshPackage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial sync with settings
    final showSystem = ref.read(settingsProvider).showSystemApps;
    context.read<PermissionBloc>().add(ShowSystemAppsChanged(showSystem));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Fires when user returns from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingRefreshPackage != null) {
      context.read<PermissionBloc>().add(RefreshApp(_pendingRefreshPackage!));
      _pendingRefreshPackage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes to update list visibility
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.showSystemApps != next.showSystemApps) {
        context.read<PermissionBloc>().add(
          ShowSystemAppsChanged(next.showSystemApps),
        );
      }
    });

    return BlocConsumer<PermissionBloc, PermissionState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context, state),
            ],
            body: Column(
              children: [
                // Method banner — shows how permissions are being controlled
                if (state.capabilities != null)
                  PermissionMethodBanner(
                    capabilities: state.capabilities!,
                    onSetupShizuku: () => _showShizukuSetup(context),
                  ),

                // Batch action bar — slides up when apps are selected
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: state.hasSelection
                      ? _buildBatchActionBar(context, state)
                      : const SizedBox.shrink(),
                ),

                // Main list
                Expanded(child: _buildList(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, PermissionState state) {
    final theme = Theme.of(context);
    return SliverAppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      floating: true,
      pinned: false,
      title: Row(
        children: [
          Icon(
            Icons.shield_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'PermGuard',
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),

      actions: [
        IconButton(
          icon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => _showSearch(context),
        ),
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => _showFilterSheet(context, state),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => context.read<PermissionBloc>().add(LoadApps()),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, PermissionState state) {
    final theme = Theme.of(context);
    if (state.status == PermissionStatus.loading) {
      return _buildShimmer();
    }

    if (state.status == PermissionStatus.error) {
      return _buildError(context, state.errorMessage ?? 'Unknown error');
    }

    final apps = state.filteredApps;

    if (apps.isEmpty) {
      return _buildEmpty(state);
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<PermissionBloc>().add(LoadApps()),
      color: theme.colorScheme.primary,
      backgroundColor: theme.cardColor,
      child: ListView.separated(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final app = apps[index];
          return AppPermissionTile(
            app: app,
            isMultiSelectMode: state.hasSelection,
            onToggle: (perm, val) {
              context.read<PermissionBloc>().add(
                TogglePermission(
                  packageName: app.packageName,
                  permission: perm,
                  allow: val,
                ),
              );
            },
            onManage: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<PermissionBloc>(),
                    child: AppDetailsScreen(packageName: app.packageName),
                  ),
                ),
              );
            },
            onSelectionToggle: () {
              context.read<PermissionBloc>().add(
                ToggleAppSelected(app.packageName),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBatchActionBar(BuildContext context, PermissionState state) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${state.selectedApps.length} selected',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                context.read<PermissionBloc>().add(BatchToggle(allow: true)),
            icon: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF22C55E),
              size: 18,
            ),
            label: const Text(
              'Allow All',
              style: TextStyle(color: Color(0xFF22C55E)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () =>
                context.read<PermissionBloc>().add(BatchToggle(allow: false)),
            icon: const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFEF4444),
              size: 18,
            ),
            label: const Text(
              'Revoke All',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            onPressed: () =>
                context.read<PermissionBloc>().add(ClearSelection()),
          ),
        ],
      ),
    );
  }

  void _handleStateChanges(BuildContext context, PermissionState state) {
    final theme = Theme.of(context);
    final result = state.lastToggleResult;
    if (result == null) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                result.message,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result.requiresShizuku) {
      _showShizukuSetup(context);
    }
  }

  void _showShizukuSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PermissionBloc>(),
        child: const ShizukuSetupSheet(),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _AppSearchDelegate(context.read<PermissionBloc>()),
    );
  }

  void _showFilterSheet(BuildContext context, PermissionState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        currentFilter: state.filter,
        onFilterSelected: (f) {
          context.read<PermissionBloc>().add(FilterChanged(f));
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _ShimmerTile(),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load apps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<PermissionBloc>().add(LoadApps()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(PermissionState state) {
    // Note: This method needs context or theme. Let's get it from the state's widget context if available or assume it's used in a context-aware way.
    // Actually, I'll pass context to it if possible or use a GlobalKey if needed, but here I'll just change the signature or get it from Builder.
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_rounded,
                color: theme.colorScheme.primary,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'All Clear!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'No apps match the current filter',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final PermissionFilter currentFilter;
  final ValueChanged<PermissionFilter> onFilterSelected;

  const _FilterSheet({
    required this.currentFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Filter Apps',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...PermissionFilter.values.map((f) {
            final labels = {
              PermissionFilter.all: ('All Apps', Icons.apps_rounded),
              PermissionFilter.withLocation: (
                'Location',
                Icons.location_on_outlined,
              ),
              PermissionFilter.withCamera: (
                'Camera',
                Icons.camera_alt_outlined,
              ),
              PermissionFilter.withMicrophone: ('Mic', Icons.mic_none_outlined),
              PermissionFilter.withStorage: (
                'Storage',
                Icons.folder_open_outlined,
              ),
              PermissionFilter.background: (
                'Background',
                Icons.history_outlined,
              ),
              PermissionFilter.activeNow: (
                'Active',
                Icons.auto_awesome_outlined,
              ),
            };
            final (label, icon) = labels[f]!;
            final isSelected = f == currentFilter;
            return ListTile(
              leading: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color?.withOpacity(0.5),
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () => onFilterSelected(f),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AppSearchDelegate extends SearchDelegate<String> {
  final PermissionBloc bloc;
  _AppSearchDelegate(this.bloc);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme,
      inputDecorationTheme: theme.inputDecorationTheme,
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) {
    bloc.add(SearchChanged(query));
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    bloc.add(SearchChanged(query));
    return const SizedBox.shrink();
  }
}
