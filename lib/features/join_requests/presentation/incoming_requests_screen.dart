import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_event.dart';
import '../../../core/realtime/notification_providers.dart';
import '../../../core/network/api_error.dart';
import '../data/join_requests_providers.dart';
import '../domain/join_request.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  final String activityId;
  const IncomingRequestsScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider(activityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Requests')),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (requests) {
          if (requests.isEmpty)
            return const Center(child: Text('No requests yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) => _IncomingRequestCard(
              request: requests[i],
              onHandled: () =>
                  ref.invalidate(incomingRequestsProvider(activityId)),
            ),
          );
        },
      ),
    );
  }
}

class _IncomingRequestCard extends ConsumerStatefulWidget {
  final JoinRequest request;
  final VoidCallback onHandled;
  const _IncomingRequestCard({required this.request, required this.onHandled});

  @override
  ConsumerState<_IncomingRequestCard> createState() =>
      _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<_IncomingRequestCard> {
  bool _isProcessing = false;

  Future<void> _accept() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(joinRequestsRepositoryProvider)
          .acceptJoinRequest(widget.request.id);
      widget.onHandled();

      final activityId = widget.request.activityPostId;
      if (activityId != null) {
        final result = await ref
            .read(notificationSocketServiceProvider)
            .events
            .firstWhere(
              (e) => e.activityId == activityId && e.groupId != null,
              orElse: () => const NotificationEvent(event: 'timeout'),
            )
            .timeout(
              const Duration(seconds: 4),
              onTimeout: () => const NotificationEvent(event: 'timeout'),
            );
        if (result.groupId != null && mounted) {
          context.push('/group/${result.groupId}/chat');
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(joinRequestsRepositoryProvider)
          .declineJoinRequest(widget.request.id);
      widget.onHandled();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final isPending = r.status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.requester?.fullName.isNotEmpty == true
                  ? r.requester!.fullName
                  : 'Requester',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (r.requester != null)
              Text(
                'Trust: ${r.requester!.trustTier} · ${r.requester!.verificationStatus}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (r.message != null && r.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.message!),
            ],
            const SizedBox(height: 12),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _accept,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              )
            else
              Chip(label: Text(r.status)),
          ],
        ),
      ),
    );
  }
}
