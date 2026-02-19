import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/channel/permission_channel.dart';

final iconProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  packageName,
) async {
  final channel = PermissionChannel(); // Normally injected but for simplicity
  return await channel.getAppIcon(packageName);
});

class LazyAppIcon extends ConsumerWidget {
  final String packageName;
  final double size;

  const LazyAppIcon({super.key, required this.packageName, this.size = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconAsync = ref.watch(iconProvider(packageName));

    return iconAsync.when(
      data: (bytes) => bytes != null
          ? Image.memory(
              bytes,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => _buildFallback(),
            )
          : _buildFallback(),
      loading: () => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Icon(Icons.android, size: size, color: Colors.grey);
  }
}
