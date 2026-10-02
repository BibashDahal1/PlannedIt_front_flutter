import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../activities/data/activities_providers.dart';
import '../data/join_requests_providers.dart';
import '../domain/join_request.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sent'),
              Tab(text: 'My Activities'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SentRequestsTab(ref: ref),
            _MyActivitiesTab(ref: ref),
          ],
        ),
      ),
    );
  }
}

class _SentRequestsTab extends ConsumerWidget {
  final WidgetRef ref;
  const _SentRequestsTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myJoinRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (requests) {
        if (requests.isEmpty)
          return const Center(child: Text('No requests sent yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, i) => _RequestTile(request: requests[i]),
        );
      },
    );
  }
}

class _MyActivitiesTab extends ConsumerWidget {
  final WidgetRef ref;
  const _MyActivitiesTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myActivitiesAsync = ref.watch(myActivitiesProvider);
    return myActivitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load: $e')),
      data: (activities) {
        if (activities.isEmpty)
          return const Center(
            child: Text("You haven't posted any activities yet."),
          );
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, i) {
            final activity = activities[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(activity.category.icon),
                title: Text(activity.title),
                subtitle: Text('Status: ${activity.status}'),
                trailing: TextButton(
                  onPressed: () =>
                      context.push('/activity/${activity.id}/requests'),
                  child: const Text('View requests'),
                ),
              ),
            );
          },
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
      ),
    );
  }
}
