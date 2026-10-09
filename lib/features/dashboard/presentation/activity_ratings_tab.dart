import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../trust/data/trust_providers.dart';
import '../../trust/domain/pending_activity_rating.dart';
import '../../trust/domain/rating.dart';
import 'dashboard_widgets.dart';

enum _RatingSubmissionResult { submitted, alreadySubmitted }

class ActivityRatingsTab extends ConsumerStatefulWidget {
  final String groupId;

  const ActivityRatingsTab({super.key, required this.groupId});

  @override
  ConsumerState<ActivityRatingsTab> createState() => _ActivityRatingsTabState();
}

class _ActivityRatingsTabState extends ConsumerState<ActivityRatingsTab> {
  @override
  Widget build(BuildContext context) {
    final pendingRatingsAsync = ref.watch(pendingRatingsProvider);
    return pendingRatingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DashboardError(
        message:
            'Could not load pending ratings: '
            '${extractApiErrorMessage(error)}',
        onRetry: () => ref.invalidate(pendingRatingsProvider),
      ),
      data: (activities) => _buildPendingRatings(
        activities
            .where((activity) => activity.groupId == widget.groupId)
            .toList(growable: false),
      ),
    );
  }

  Widget _buildPendingRatings(List<PendingActivityRating> activities) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(pendingRatingsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Text(
            'Ratings to complete',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Rate the activity members listed below. These are the ratings '
            'currently pending for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (activities.isEmpty)
            SketchBox(
              seed: widget.groupId.hashCode,
              radius: 16,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'There are no pending ratings for this activity group.',
              ),
            )
          else
            Column(
              children: [
                for (final activity in activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SketchBox(
                      seed: activity.activityId.hashCode,
                      radius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.activityTitle.isEmpty
                                ? 'Activity'
                                : activity.activityTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your role: ${activity.myRole.isEmpty ? 'Member' : activity.myRole} '
                            '· Ended ${_formatEndTime(activity.scheduledEnd)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          for (final ratee in activity.ratees)
                            _RateeRow(
                              ratee: ratee,
                              onRate: () => _showRatingSheet(
                                activityId: activity.activityId,
                                ratee: ratee,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatEndTime(DateTime scheduledEnd) =>
      '${scheduledEnd.day}/${scheduledEnd.month} '
      '${scheduledEnd.hour.toString().padLeft(2, '0')}:'
      '${scheduledEnd.minute.toString().padLeft(2, '0')}';

  Future<void> _showRatingSheet({
    required String activityId,
    required PendingRatee ratee,
  }) async {
    var score = 5;
    var selectedTags = <String>{};
    var isSubmitting = false;
    final commentController = TextEditingController();
    final result = await showModalBottomSheet<_RatingSubmissionResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rate ${ratee.fullName.isEmpty ? 'member' : ratee.fullName}',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Choose a score from 1 to 5.'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        IconButton(
                          tooltip: '$value star${value == 1 ? '' : 's'}',
                          onPressed: isSubmitting
                              ? null
                              : () => setSheetState(() => score = value),
                          icon: Icon(
                            value <= score ? Icons.star : Icons.star_border,
                            color: Colors.amber.shade700,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (tag, label) in ratingTags)
                        FilterChip(
                          label: Text(label),
                          selected: selectedTags.contains(tag),
                          onSelected: isSubmitting
                              ? null
                              : (selected) => setSheetState(() {
                                  if (selected) {
                                    selectedTags.add(tag);
                                  } else {
                                    selectedTags.remove(tag);
                                  }
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    enabled: !isSubmitting,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            try {
                              await ref
                                  .read(trustRepositoryProvider)
                                  .submitRating(
                                    activityId,
                                    rateeId: ratee.id,
                                    score: score,
                                    comment: commentController.text.trim(),
                                    tags: selectedTags.toList(growable: false),
                                  );
                              ref.invalidate(publicProfileProvider(ratee.id));
                              ref.invalidate(pendingRatingsProvider);
                              if (sheetContext.mounted) {
                                Navigator.of(
                                  sheetContext,
                                ).pop(_RatingSubmissionResult.submitted);
                              }
                            } catch (error) {
                              if (sheetContext.mounted) {
                                if (_isAlreadyRatedError(error)) {
                                  ref.invalidate(
                                    publicProfileProvider(ratee.id),
                                  );
                                  ref.invalidate(pendingRatingsProvider);
                                  Navigator.of(sheetContext).pop(
                                    _RatingSubmissionResult.alreadySubmitted,
                                  );
                                  return;
                                }
                                setSheetState(() => isSubmitting = false);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      extractApiErrorMessage(error),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit rating'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    commentController.dispose();
    if (!mounted || result == null) return;
    final displayName = ratee.fullName.isEmpty ? 'member' : ratee.fullName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == _RatingSubmissionResult.submitted
              ? 'Rating sent to $displayName.'
              : 'You already rated $displayName for this activity.',
        ),
      ),
    );
  }

  bool _isAlreadyRatedError(Object error) {
    if (error is! DioException) return false;
    final data = error.response?.data;
    if (data is! Map) return false;
    final errors = data['non_field_errors'];
    final messages = errors is List ? errors : [errors];
    return messages.any(
      (message) => message.toString().toLowerCase().contains(
        "already rated this person for this activity",
      ),
    );
  }
}

class _RateeRow extends StatelessWidget {
  final PendingRatee ratee;
  final VoidCallback onRate;

  const _RateeRow({required this.ratee, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final name = ratee.fullName.isEmpty
        ? (ratee.role.toLowerCase() == 'host' ? 'Host' : 'Member')
        : ratee.fullName;
    return Row(
      children: [
        UserAvatar(avatarUrl: ratee.avatar, radius: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (ratee.role.toLowerCase() == 'host')
                Text(
                  'Activity host',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        OutlinedButton(onPressed: onRate, child: const Text('Rate')),
      ],
    );
  }
}
