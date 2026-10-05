import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import 'edit_profile_screen.dart';
import '../../../core/theme/theme_mode_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: authState.when(
        data: (state) {
          if (!state.isLoggedIn || state.user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SketchBox(
                  radius: 20,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SketchIcon('profile', size: 56),
                      const SizedBox(height: 12),
                      const Text(
                        "You're not logged in.",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      SketchButton(
                        label: 'Log in',
                        icon: const Icon(Icons.login),
                        filled: true,
                        onPressed: () => context.push('/login'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final user = state.user!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SketchButton(
                      label: 'Edit Profile',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(user: user),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SketchButton(
                      label: 'My Dashboard',
                      icon: const Icon(Icons.dashboard_outlined),
                      onPressed: () => context.push('/dashboard'),
                      seed: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'About me',
                icon: const SketchIcon('profile', size: 23),
              ),
              const SizedBox(height: 10),
              SketchBox(
                seed: user.id.hashCode,
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: const Icon(Icons.email_outlined),
                      label: 'Email',
                      value: user.email?.isNotEmpty == true
                          ? user.email!
                          : 'Not set',
                    ),
                    _InfoRow(
                      icon: const Icon(Icons.cake_outlined),
                      label: 'Date of birth',
                      value: user.dateOfBirth == null
                          ? 'Not set'
                          : _formatDate(user.dateOfBirth!),
                    ),
                    _InfoRow(
                      icon: const Icon(Icons.verified_user_outlined),
                      label: 'Verification',
                      value: _displayLabel(user.verificationStatus),
                    ),
                    _InfoRow(
                      icon: const Icon(Icons.star_outline),
                      label: 'Trust tier',
                      value: _displayLabel(user.trustTier),
                    ),
                    _InfoRow(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: 'Member since',
                      value: _formatDate(user.dateJoined),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              if (user.socialProfiles.isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionHeading(
                  title: 'Social profiles',
                  icon: const SketchIcon('social_table', size: 24),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < user.socialProfiles.length; i++) ...[
                  _SocialProfileCard(
                    platform: user.socialProfiles[i].platform,
                    username: user.socialProfiles[i].username,
                    profileUrl: user.socialProfiles[i].profileUrl,
                    seed: user.socialProfiles[i].platform.hashCode + i,
                  ),
                  if (i != user.socialProfiles.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'Preferences',
                icon: const SketchIcon('settings', size: 23),
              ),
              const SizedBox(height: 10),
              SketchBox(
                seed: 30,
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final mode = ref.watch(themeModeProvider);
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Dark mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        mode == ThemeMode.dark ? 'On' : 'Off',
                        style: TextStyle(color: SketchColors.inkFaint),
                      ),
                      secondary: const SketchIcon('settings', size: 24),
                      value: mode == ThemeMode.dark,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SketchButton(
                label: 'Privacy Policy & Terms of Service',
                icon: const Icon(Icons.description_outlined),
                onPressed: () => context.push('/legal/privacy_terms'),
                seed: 31,
              ),
              const SizedBox(height: 24),
              SketchButton(
                label: 'Log out',
                icon: const Icon(Icons.logout),
                danger: true,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                seed: 32,
              ),
            ],
          );
        },
        loading: () => Center(
          child: SketchBox(
            radius: 18,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: SketchColors.ink),
                const SizedBox(height: 12),
                const Text('Loading your profile...'),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SketchBox(
              radius: 18,
              padding: const EdgeInsets.all(20),
              child: Text(
                'Something went wrong: $e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: user.id.hashCode + 1,
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SketchBox(
            seed: user.id.hashCode + 2,
            radius: 52,
            width: 100,
            height: 100,
            child: Center(
              child: UserAvatar(avatarUrl: user.avatar, radius: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName.isEmpty ? 'No name set' : user.fullName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            user.phoneNumber,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: SketchColors.inkFaint),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProfileBadge(
                icon: const Icon(Icons.verified_user_outlined),
                label: _displayLabel(user.verificationStatus),
                seed: user.verificationStatus.hashCode,
              ),
              _ProfileBadge(
                icon: const Icon(Icons.star_outline),
                label: _displayLabel(user.trustTier),
                seed: user.trustTier.hashCode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final Widget icon;
  final String label;
  final int seed;

  const _ProfileBadge({
    required this.icon,
    required this.label,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: seed,
      radius: 12,
      fill: null,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(color: SketchColors.ink, size: 16),
            child: icon,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final Widget icon;
  const _SectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLast ? 9 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTheme(
            data: IconThemeData(color: SketchColors.ink, size: 21),
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: SketchColors.inkFaint),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialProfileCard extends StatelessWidget {
  final String platform;
  final String? username;
  final String? profileUrl;
  final int seed;

  const _SocialProfileCard({
    required this.platform,
    required this.username,
    required this.profileUrl,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (username?.isNotEmpty == true) username!,
      if (profileUrl?.isNotEmpty == true) profileUrl!,
    ];

    return SketchBox(
      seed: seed,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SketchBox(
            seed: seed + 1,
            radius: 12,
            width: 42,
            height: 42,
            child: Center(
              child: Icon(
                _socialPlatformIcon(platform),
                color: SketchColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final detail in details)
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SketchColors.inkFaint,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayLabel(String value) {
  if (value.isEmpty) return 'Not set';
  return value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

IconData _socialPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'instagram':
      return Icons.camera_alt_outlined;
    case 'facebook':
      return Icons.facebook;
    case 'tiktok':
      return Icons.music_note;
    case 'x':
      return Icons.close;
    case 'linkedin':
      return Icons.work_outline;
    case 'youtube':
      return Icons.smart_display_outlined;
    case 'snapchat':
      return Icons.photo_camera_outlined;
    default:
      return Icons.link;
  }
}
