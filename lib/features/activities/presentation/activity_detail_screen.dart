import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/social_groups_providers.dart'; // NEW
import '../../join_requests/data/join_requests_providers.dart';
import '../../join_requests/presentation/apply_with_group_sheet.dart'; // NEW
import '../../trust/data/trust_providers.dart';
import '../data/activities_providers.dart';
import '../../../core/realtime/notification_providers.dart';
import 'edit_activity_screen.dart';
import '../domain/activity_post.dart';
import 'widgets/activity_location_map.dart';
import '../../../core/widgets/user_avatar.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  final String activityId;
  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  bool _isRequesting = false;
  bool _isCompleting = false;

  Future<void> _requestToJoin() async {
    setState(() => _isRequesting = true);
    try {
      await ref
          .read(joinRequestsRepositoryProvider)
          .sendJoinRequest(widget.activityId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request sent! You\'ll be notified once the host responds.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  /// NEW: a group admin applies with their social group and picks who applies.
  Future<void> _applyWithGroup() async {
    final applied = await ApplyWithGroupSheet.show(
      context,
      activityId: widget.activityId,
    );
    if (applied == true && mounted) {
      ref.invalidate(myJoinRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Group request sent! You\'ll be notified once the host responds.',
          ),
        ),
      );
    }
  }

  Future<void> _markComplete() async {
    setState(() => _isCompleting = true);
    try {
      await ref
          .read(trustRepositoryProvider)
          .completeActivity(widget.activityId);
      if (!mounted) return;
      ref.invalidate(activityDetailProvider(widget.activityId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity marked as complete.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _cancelActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this activity?'),
        content: const Text(
          'Everyone already accepted will be notified. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Activity'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(activitiesRepositoryProvider)
          .cancelActivity(widget.activityId);
      ref.invalidate(activityDetailProvider(widget.activityId));
      ref.invalidate(myActivitiesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity cancelled.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
      }
    }
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: const Text(
          'This permanently deletes the activity, its chat history, and all join requests. '
          'Everyone involved will be notified. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(activitiesRepositoryProvider)
          .deleteActivity(widget.activityId);
      ref.invalidate(myActivitiesProvider);
      ref.invalidate(activityFeedProvider(null));
      ref.invalidate(nearbyActivitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activity deleted.')));
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    final authState = ref.watch(authControllerProvider);

    // NEW: only show "Apply with a group" to people who admin a social group.
    final hasAdminGroup = ref
        .watch(mySocialGroupsProvider)
        .maybeWhen(
          data: (groups) => groups.any((g) => g.isAdmin),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load activity: $e')),
        data: (activity) {
          final currentUserId = authState.value?.user?.id;
          final isHost =
              currentUserId != null && currentUserId == activity.host.id;
          final canMarkComplete =
              isHost &&
              activity.status == 'open' &&
              DateTime.now().isAfter(activity.scheduledEnd);
          final isOpenForActions =
              activity.status != 'cancelled' && activity.status != 'completed';
          final groupLink = ref.watch(activityGroupLinksProvider)[activity.id];

          final mine = isHost
              ? ref
                    .watch(myActivitiesProvider)
                    .maybeWhen(
                      data: (d) => d,
                      orElse: () => const <ActivityPost>[],
                    )
              : const <ActivityPost>[];
          final exactMatches = mine.where((m) => m.id == activity.id);
          final displayLocation = exactMatches.isEmpty
              ? activity.location
              : exactMatches.first.location;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SketchBox(
                  seed: activity.id.hashCode,
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SketchBox(
                            seed: activity.category.name.hashCode,
                            radius: 14,
                            width: 54,
                            height: 54,
                            child: Center(
                              child: CategoryIcon(
                                activity.category.name,
                                iconKey: activity.category.iconKey,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                Text(
                                  activity.category.name,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: SketchColors.inkFaint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (activity.description != null &&
                          activity.description!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const SketchUnderline(width: 72),
                        const SizedBox(height: 8),
                        Text(
                          activity.description!,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SketchBox(
                  seed: activity.id.hashCode + 1,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: const SketchIcon('pin', size: 22),
                        label:
                            displayLocation.venueName ??
                            displayLocation.addressText ??
                            'Nearby',
                      ),
                      _DetailRow(
                        icon: const SketchIcon('calendar', size: 22),
                        label:
                            '${_formatDateTime(activity.scheduledStart)} – ${_formatTime(activity.scheduledEnd)}',
                      ),
                      _DetailRow(
                        icon: const SketchIcon('people', size: 22),
                        label:
                            '${activity.totalSpotsNeeded} spots needed'
                            '${activity.teamSize != null ? ' · team size ${activity.teamSize}' : ''}',
                      ),
                      _DetailRow(
                        icon: const Icon(Icons.receipt_long_outlined, size: 22),
                        label: activity.costSharingEnabled
                            ? 'Shared costs enabled'
                            : 'Shared costs disabled',
                      ),
                      if (activity.minVerificationTier != null)
                        _DetailRow(
                          icon: const Icon(Icons.verified_user_outlined),
                          label:
                              'Min. verification: ${activity.minVerificationTier}',
                        ),
                    ],
                  ),
                ),
                if (isHost && !activity.costSharingEnabled) ...[
                  const SizedBox(height: 10),
                  SketchButton(
                    label: 'Enable shared costs',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditActivityScreen(
                          activity: activity,
                          location: displayLocation,
                          groupId: groupLink?.groupId,
                        ),
                      ),
                    ),
                    seed: activity.id.hashCode + 2,
                  ),
                ],
                const SizedBox(height: 16),
                SketchBox(
                  seed: activity.id.hashCode + 3,
                  radius: 18,
                  padding: const EdgeInsets.all(4),
                  child: ActivityLocationMap(location: displayLocation),
                ),
                const SizedBox(height: 12),
                if (groupLink != null) ...[
                  SketchButton(
                    label: 'Open Group Chat',
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () =>
                        context.push('/group/${groupLink.groupId}/chat'),
                    seed: activity.id.hashCode + 4,
                  ),
                  const SizedBox(height: 12),
                ],
                SketchBox(
                  seed: activity.host.id.hashCode,
                  radius: 16,
                  padding: const EdgeInsets.all(14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(
                        '/profile/${activity.host.id}/public?activityId=${activity.id}',
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: activity.host.avatar,
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.host.fullName.isEmpty
                                      ? 'Host'
                                      : activity.host.fullName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  'Trust tier: ${activity.host.trustTier} · ${activity.host.verificationStatus}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: SketchColors.inkFaint),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (isHost) ...[
                  SketchButton(
                    label: 'View incoming requests',
                    icon: const Icon(Icons.inbox_outlined),
                    onPressed: () =>
                        context.push('/activity/${activity.id}/requests'),
                    filled: true,
                    seed: activity.id.hashCode + 5,
                  ),
                  if (isOpenForActions) ...[
                    const SizedBox(height: 12),
                    SketchButton(
                      label: 'Edit Activity',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditActivityScreen(
                            activity: activity,
                            location: displayLocation,
                            groupId: groupLink?.groupId,
                          ),
                        ),
                      ),
                      seed: activity.id.hashCode + 6,
                    ),
                    const SizedBox(height: 12),
                    SketchButton(
                      label: 'Cancel Activity',
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      onPressed: _cancelActivity,
                      danger: true,
                      seed: activity.id.hashCode + 7,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SketchButton(
                    label: 'Delete Activity',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: _deleteActivity,
                    danger: true,
                    seed: activity.id.hashCode + 8,
                  ),
                  if (canMarkComplete) ...[
                    const SizedBox(height: 12),
                    SketchButton(
                      label: 'Mark as Complete',
                      onPressed: _isCompleting ? null : _markComplete,
                      isLoading: _isCompleting,
                      seed: activity.id.hashCode + 9,
                    ),
                  ],
                ] else if (activity.status == 'open') ...[
                  SketchButton(
                    label: 'Request to Join',
                    onPressed: _isRequesting ? null : _requestToJoin,
                    filled: true,
                    isLoading: _isRequesting,
                    seed: activity.id.hashCode + 10,
                  ),
                  // NEW: shown only to admins of a social group.
                  if (hasAdminGroup) ...[
                    const SizedBox(height: 12),
                    SketchButton(
                      label: 'Apply with a group',
                      icon: const Icon(Icons.group_add),
                      onPressed: _applyWithGroup,
                      seed: activity.id.hashCode + 12,
                    ),
                  ],
                ] else
                  SketchButton(
                    label: 'This activity is ${activity.status}',
                    onPressed: null,
                    seed: activity.id.hashCode + 11,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month} ${_formatTime(dt)}';
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final Widget icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
