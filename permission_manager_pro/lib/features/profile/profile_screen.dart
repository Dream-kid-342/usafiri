import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_manager_pro/core/supabase_client.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../settings/presentation/settings_screen.dart' as com_settings;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName;

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: imageFile.mimeType),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': imageUrl}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error occurred'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch auth state changes to rebuild UI when metadata updates
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata;
    final email = user?.email ?? 'Unknown';
    final phone = metadata?['phone'] ?? 'Not set';
    final role = metadata?['role'] ?? 'client';
    final avatarUrl = metadata?['avatar_url'];

    // Nested Scaffold for background color, but NO AppBar to avoid duplication
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  if (avatarUrl != null)
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(avatarUrl),
                      backgroundColor: theme.colorScheme.primary.withOpacity(
                        0.1,
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_isLoading)
                    const Positioned.fill(child: CircularProgressIndicator()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        onPressed: _isLoading ? null : _uploadAvatar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              email,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              role.toString().toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),

            // Info Cards
            _buildInfoTile(context, Icons.email, 'Email', email),
            _buildInfoTile(context, Icons.phone, 'Phone', phone),
            _buildInfoTile(
              context,
              Icons.security,
              'Subscription',
              metadata?['subscription_status'] == 'active'
                  ? 'PRO Member'
                  : 'Free Trial',
              color: metadata?['subscription_status'] == 'active'
                  ? Colors.green
                  : Colors.orange,
            ),
            if (metadata?['subscription_status'] != 'active')
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  'Trial Expires: ${metadata?['trial_expires_at']?.toString().split(' ')[0] ?? 'N/A'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Settings Tile
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceVariant,
              margin: const EdgeInsets.only(bottom: 24),
              child: ListTile(
                leading: Icon(Icons.settings, color: theme.colorScheme.primary),
                title: Text(
                  'Settings',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                subtitle: Text(
                  'Theme, System Apps, Account',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const com_settings.SettingsScreen(),
                    ),
                  );
                },
              ),
            ),

            // Actions
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String title,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5), // Themed card
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: title == 'Phone'
            ? IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () => _showEditProfileDialog(
                  context,
                  supabase.auth.currentUser?.userMetadata,
                ),
              )
            : null,
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    Map<String, dynamic>? metadata,
  ) {
    final phoneController = TextEditingController(
      text: metadata?['phone'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '254...',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await supabase.auth.updateUser(
                  UserAttributes(
                    data: {...?metadata, 'phone': phoneController.text},
                  ),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh UI
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
