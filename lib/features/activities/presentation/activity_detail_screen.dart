import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../join_requests/data/join_requests_providers.dart';
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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CategoryIcon(activity.category.name, size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            activity.category.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (activity.description != null) ...[
                  Text(
                    activity.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                ],
                _DetailRow(
                  icon: const SketchIcon('pin', size: 18),
                  label:
                      displayLocation.venueName ??
                      displayLocation.addressText ??
                      'Nearby',
                ),
                _DetailRow(
                  icon: const SketchIcon('calendar', size: 18),
                  label:
                      '${_formatDateTime(activity.scheduledStart)} – ${_formatTime(activity.scheduledEnd)}',
                ),
                _DetailRow(
                  icon: const SketchIcon('people', size: 18),
                  label:
                      '${activity.totalSpotsNeeded} spots needed'
                      '${activity.teamSize != null ? ' · team size ${activity.teamSize}' : ''}',
                ),
                if (activity.minVerificationTier != null)
                  _DetailRow(
                    icon: const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    label: 'Min. verification: ${activity.minVerificationTier}',
                  ),
                const SizedBox(height: 12),
                ActivityLocationMap(location: displayLocation),
                const SizedBox(height: 12),
                if (groupLink != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open Group Chat'),
                    onPressed: () =>
                        context.push('/group/${groupLink.groupId}/chat'),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(
                      '/profile/${activity.host.id}/public?activityId=${activity.id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: activity.host.avatar,
                            radius: 20,
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
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (isHost) ...[
                  ElevatedButton(
                    onPressed: () =>
                        context.push('/activity/${activity.id}/requests'),
                    child: const Text('View incoming requests'),
                  ),
                  if (isOpenForActions) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Activity'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditActivityScreen(
                            activity: activity,
                            location: displayLocation,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Cancel Activity',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: _cancelActivity,
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    label: const Text(
                      'Delete Activity',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    onPressed: _deleteActivity,
                  ),
                  if (canMarkComplete) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isCompleting ? null : _markComplete,
                      child: _isCompleting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Mark as Complete'),
                    ),
                  ],
                ] else if (activity.status == 'open')
                  ElevatedButton(
                    onPressed: _isRequesting ? null : _requestToJoin,
                    child: _isRequesting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Request to Join'),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    child: Text('This activity is ${activity.status}'),
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
