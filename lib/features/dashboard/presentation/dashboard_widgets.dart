import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../activities/data/activities_providers.dart';
import '../../groups/data/groups_providers.dart';
class GroupActivityIcon extends ConsumerWidget {
  final String groupId;
  final double size;

  const GroupActivityIcon({
    super.key,
    required this.groupId,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(groupRosterProvider(groupId));
    return rosterAsync.when(
      data: (roster) {
        final activityAsync = ref.watch(
          activityDetailProvider(roster.activityId),
        );
        return activityAsync.when(
          data: (activity) => CategoryIcon(activity.category.name, size: size),
          loading: () => SketchIcon('calendar', size: size),
          error: (_, _) => SketchIcon('calendar', size: size),
        );
      },
      loading: () => SketchIcon('calendar', size: size),
      error: (_, _) => SketchIcon('calendar', size: size),
    );
  }
}

class DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DashboardError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SketchBox(
        seed: message.hashCode,
        radius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}
