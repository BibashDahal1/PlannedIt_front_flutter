import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../activities/data/activities_providers.dart';
import '../../activities/domain/activity_post.dart';
import '../../join_requests/data/join_requests_providers.dart';
import '../../join_requests/domain/join_request.dart';
import '../../../core/widgets/sketch_icon.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Activities'),
              Tab(text: 'Sent Requests'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MyActivitiesTab(), _SentRequestsTab()],
        ),
      ),
    );
  }
}

class _MyActivitiesTab extends ConsumerWidget {
  const _MyActivitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myActivitiesAsync = ref.watch(myActivitiesProvider);
    return myActivitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (activities) {
        if (activities.isEmpty) {
          return const Center(
            child: Text("You haven't posted any activities yet."),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myActivitiesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, i) =>
                _MyActivityCard(activity: activities[i]),
          ),
        );
      },
    );
  }
}

class _MyActivityCard extends StatelessWidget {
  final ActivityPost activity;
  const _MyActivityCard({required this.activity});

  Color _statusColor() {
    switch (activity.status) {
      case 'open':
        return Colors.green;
      case 'full':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CategoryIcon(activity.category.name, size: 24),
        title: Text(activity.title),
        subtitle: Text(
          activity.location.venueName ??
              activity.location.addressText ??
              'Nearby',
        ),
        trailing: Chip(
          label: Text(
            activity.status,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          backgroundColor: _statusColor(),
        ),
        onTap: () => context.push('/activity/${activity.id}'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (requests) {
        if (requests.isEmpty)
          return const Center(child: Text('No requests sent yet.'));
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myJoinRequestsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) => _RequestTile(request: requests[i]),
          ),
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  const _RequestTile({required this.request});

  Color _statusColor() {
    switch (request.status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(request.activityTitle ?? 'Activity'),
        subtitle: Text(request.message ?? ''),
        trailing: Chip(
          label: Text(
            request.status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: _statusColor(),
        ),
        onTap: request.activityPostId != null
            ? () => context.push('/activity/${request.activityPostId}')
            : null,
      ),
    );
  }
}
