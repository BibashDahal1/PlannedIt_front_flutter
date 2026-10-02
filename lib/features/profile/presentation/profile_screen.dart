import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import 'edit_profile_screen.dart';
// import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import 'package:flutter/material.dart' show ThemeMode;
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_icon.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: authState.when(
        data: (state) {
          if (!state.isLoggedIn || state.user == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("You're not logged in."),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            );
          }
          final user = state.user!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: UserAvatar(avatarUrl: user.avatar, radius: 44)),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.fullName.isEmpty ? 'No name set' : user.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Center(
                child: Text(
                  user.phoneNumber,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(user: user),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text('My Dashboard'),
                  onPressed: () => context.push('/dashboard'),
                ),
              ),
              const SizedBox(height: 24),
              if (user.dateOfBirth != null)
                _InfoRow(
                  label: 'Date of birth',
                  value:
                      '${user.dateOfBirth!.year}-${user.dateOfBirth!.month.toString().padLeft(2, '0')}-${user.dateOfBirth!.day.toString().padLeft(2, '0')}',
                ),
              _InfoRow(label: 'Verification', value: user.verificationStatus),
              _InfoRow(label: 'Trust tier', value: user.trustTier),
              _InfoRow(
                label: 'Member since',
                value:
                    '${user.dateJoined.year}-${user.dateJoined.month.toString().padLeft(2, '0')}-${user.dateJoined.day.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(themeModeProvider);
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dark mode'),
                    secondary: const SketchIcon('settings', size: 22),
                    value: mode == ThemeMode.dark,
                    onChanged: (_) =>
                        ref.read(themeModeProvider.notifier).toggle(),
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/legal/privacy_terms'),
                  child: const Text('Privacy Policy & Terms of Service'),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Log out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
