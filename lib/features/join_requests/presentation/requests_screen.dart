import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../activities/data/activities_providers.dart';
import '../../groups/data/social_groups_providers.dart'; // NEW
import '../../groups/presentation/social_group_invitations_tab.dart'; // NEW
import '../data/group_applications.dart'; // NEW
import '../data/join_requests_providers.dart';
import '../domain/join_request.dart';
import 'group_applicants_picker.dart'; // NEW

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NEW: keeps invitations / groups fresh from live notifications.
    ref.watch(socialGroupLiveRefreshProvider);
    final inviteCount =
        ref.watch(socialGroupInvitationsProvider).value?.length ?? 0;

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Sent'),
              const Tab(text: 'My Activities'),
              // NEW: group invitations, with a count badge.
              Tab(
                child: Badge(
                  isLabelVisible: inviteCount > 0,
                  label: Text('$inviteCount'),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('Invitations'),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SentRequestsTab(),
            MyActivityRequestsTab(),
            SocialGroupInvitationsTab(),
          ],
        ),
      ),
    );
  }
}

class _SentRequestsTab extends ConsumerWidget {
  const _SentRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myJoinRequestsProvider);
    return requestsAsync.when(
      loading: () => Center(
        child: SketchBox(
          radius: 16,
          padding: const EdgeInsets.all(20),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading sent requests...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SketchBox(
            radius: 16,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load sent requests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  extractApiErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SketchColors.inkFaint),
                ),
                const SizedBox(height: 12),
                SketchButton(
                  label: 'Try again',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(myJoinRequestsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SketchBox(
                radius: 18,
                padding: const EdgeInsets.all(24),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SketchIcon('chat', size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No sent requests yet.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'When you request to join an activity, it will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(myJoinRequestsProvider.future).then<void>((_) {}),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: requests.length,
            itemBuilder: (context, i) => _RequestTile(request: requests[i]),
          ),
        );
      },
    );
  }
}

class MyActivityRequestsTab extends ConsumerWidget {
  const MyActivityRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myActivitiesAsync = ref.watch(myActivitiesProvider);
    return myActivitiesAsync.when(
      loading: () => Center(
        child: SketchBox(
          radius: 16,
          padding: const EdgeInsets.all(20),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading your activities...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SketchBox(
            radius: 16,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load your activities.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  extractApiErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SketchColors.inkFaint),
                ),
                const SizedBox(height: 12),
                SketchButton(
                  label: 'Try again',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(myActivitiesProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (activities) {
        if (activities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SketchBox(
                radius: 18,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SketchIcon('calendar', size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "You haven't posted any activities yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Post an activity to receive and manage join requests here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    SketchButton(
                      label: 'Post an activity',
                      icon: const Icon(Icons.add),
                      filled: true,
                      onPressed: () => context.go('/post-activity'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(myActivitiesProvider.future).then<void>((_) {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Choose one of your activities to view its incoming requests.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SketchColors.inkFaint,
                  ),
                ),
              ),
              for (final activity in activities)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SketchBox(
                    seed: activity.id.hashCode,
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SketchBox(
                          seed: activity.category.name.hashCode,
                          radius: 13,
                          width: 48,
                          height: 48,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Status: ${activity.status}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: SketchColors.inkFaint),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 108,
                          child: SketchButton(
                            label: 'Requests',
                            icon: const Icon(Icons.inbox_outlined),
                            onPressed: () => context.push(
                              '/activity/${activity.id}/requests',
                            ),
                            seed: activity.id.hashCode + 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A request I sent. For group applications it also shows the group and the
/// outcome of each applicant (pending / accepted / not selected).
class _RequestTile extends ConsumerWidget {
  final JoinRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = switch (request.status) {
      'pending' => 'Pending',
      'accepted' => 'Accepted',
      'declined' => 'Declined',
      'rejected' => 'Rejected',
      'withdrawn' => 'Withdrawn',
      _ => request.status,
    };

    // NEW: null for individual requests.
    final groupApp = ref.watch(groupApplicationProvider(request.id)).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SketchBox(
        seed: request.id.hashCode,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SketchBox(
                  seed: request.id.hashCode + 1,
                  radius: 13,
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SketchIcon(
                      groupApp != null ? 'people' : 'calendar',
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.activityTitle?.isNotEmpty == true
                            ? request.activityTitle!
                            : 'Activity',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (groupApp != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Applied with ${groupApp.groupName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SketchColors.inkFaint),
                        ),
                      ],
                      if (request.message?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          request.message!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      SketchBox(
                        seed: request.status.hashCode,
                        radius: 12,
                        fill: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: SketchColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // NEW: each applicant and their outcome (read-only).
            if (groupApp != null) ...[
              const SizedBox(height: 12),
              GroupApplicantsPicker(
                application: groupApp,
                spotsRemaining: null,
                selected: const <String>{},
                readOnly: true,
                onToggle: (_) {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}
