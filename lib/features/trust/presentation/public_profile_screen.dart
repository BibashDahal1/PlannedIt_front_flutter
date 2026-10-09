import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../data/trust_providers.dart';
import '../domain/report_reason.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/domain/social_profile.dart';
import '../../join_requests/domain/requester_preview.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  final String?
  activityId; // passed when opened from an activity's host card, so a report can reference it
  final RequesterPreview? requester;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.activityId,
    this.requester,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _showReportSheet(context, ref);
              if (value == 'block') _confirmBlock(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'report', child: Text('Report user')),
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load profile: ${extractApiErrorMessage(e)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (profile) {
          final name = profile.fullName.isNotEmpty
              ? profile.fullName
              : requester?.fullName ?? 'User';
          final avatar = profile.avatar ?? requester?.avatar;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              SketchBox(
                seed: profile.id.hashCode,
                radius: 22,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    UserAvatar(avatarUrl: avatar, radius: 46),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProfileBadge(
                          icon: Icons.verified_user_outlined,
                          label: _displayLabel(profile.verificationStatus),
                        ),
                        _ProfileBadge(
                          icon: Icons.star_outline,
                          label: _displayLabel(profile.trustTier),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: 'Rating',
                      value: profile.averageRating != null
                          ? profile.averageRating!.toStringAsFixed(1)
                          : '—',
                    ),
                  ),
                  Expanded(
                    child: _StatColumn(
                      label: 'Reviews',
                      value: '${profile.ratingsCount}',
                    ),
                  ),
                  Expanded(
                    child: _StatColumn(
                      label: 'Hosted',
                      value: '${profile.activitiesHosted}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SketchBox(
                seed: profile.id.hashCode + 1,
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    _Row(
                      label: 'Verification',
                      value: _displayLabel(profile.verificationStatus),
                    ),
                    _Row(
                      label: 'Trust tier',
                      value: _displayLabel(profile.trustTier),
                    ),
                    _Row(
                      label: 'Member since',
                      value: _formatDate(profile.dateJoined),
                    ),
                  ],
                ),
              ),
              if (requester != null) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(Icons.public, color: SketchColors.ink),
                    const SizedBox(width: 9),
                    Text(
                      'Social profiles',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (requester!.socialProfiles.isEmpty)
                  SketchBox(
                    seed: profile.id.hashCode + 2,
                    radius: 16,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No social profiles were shared with this request.',
                      style: TextStyle(color: SketchColors.inkFaint),
                    ),
                  )
                else
                  for (
                    var i = 0;
                    i < requester!.socialProfiles.length;
                    i++
                  ) ...[
                    _SocialProfileCard(
                      profile: requester!.socialProfiles[i],
                      seed: requester!.socialProfiles[i].platform.hashCode + i,
                    ),
                    if (i != requester!.socialProfiles.length - 1)
                      const SizedBox(height: 10),
                  ],
              ],
            ],
          );
        },
      ),
    );
  }

  void _showReportSheet(BuildContext context, WidgetRef ref) {
    String? selectedReason;
    final detailsController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report this user',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reportReasons
                    .map(
                      (r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedReason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(trustRepositoryProvider)
                              .submitReport(
                                reportedUserId: userId,
                                activityPostId: activityId,
                                reason: selectedReason!,
                                details: detailsController.text.trim(),
                              );
                          if (sheetContext.mounted)
                            Navigator.of(sheetContext).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(extractApiErrorMessage(e)),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBlock(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          "You won't see each other's activities. This can be undone later in Settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(trustRepositoryProvider).blockUser(userId);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(extractApiErrorMessage(e))),
                  );
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => SketchBox(
    seed: label.hashCode,
    radius: 12,
    fill: null,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: SketchColors.ink),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SocialProfileCard extends StatelessWidget {
  final SocialProfile profile;
  final int seed;

  const _SocialProfileCard({required this.profile, required this.seed});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (profile.username?.isNotEmpty == true) profile.username!,
      if (profile.profileUrl?.isNotEmpty == true) profile.profileUrl!,
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
                _socialPlatformIcon(profile.platform),
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
                  _displayLabel(profile.platform),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  for (final detail in details)
                    SelectableText(
                      detail,
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

IconData _socialPlatformIcon(String platform) =>
    switch (platform.toLowerCase()) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.facebook,
      'tiktok' => Icons.music_note,
      'x' => Icons.close,
      'linkedin' => Icons.work_outline,
      'youtube' => Icons.smart_display_outlined,
      'snapchat' => Icons.photo_camera_outlined,
      _ => Icons.link,
    };
