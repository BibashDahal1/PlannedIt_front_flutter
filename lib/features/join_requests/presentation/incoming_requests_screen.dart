import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_event.dart';
import '../../../core/realtime/notification_providers.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../groups/data/groups_providers.dart';
import '../data/group_applications.dart'; // NEW
import '../data/join_requests_providers.dart';
import '../domain/join_request.dart';
import 'group_applicants_picker.dart'; // NEW

class IncomingRequestsScreen extends ConsumerWidget {
  final String activityId;
  const IncomingRequestsScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(incomingRequestsProvider(activityId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Incoming Requests')),
      body: requestsAsync.when(
        loading: () => Center(
          child: SketchBox(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SketchColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Loading incoming requests...'),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SketchIcon('more_dots', size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load incoming requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    extractApiErrorMessage(e),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SketchColors.inkFaint),
                  ),
                  const SizedBox(height: 14),
                  SketchButton(
                    label: 'Try again',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.invalidate(incomingRequestsProvider(activityId)),
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
                      SketchIcon('people', size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No requests yet.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'New requests to join this activity will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

  // NEW: host's selection for a group application.
  final Set<String> _selectedApplicants = {};
  bool _selectionInitialized = false;

  Future<void> _accept() async {
    setState(() => _isProcessing = true);
    try {
      final activityId = widget.request.activityPostId;
      final groupEventFuture = activityId == null
          ? null
          : ref
                .read(notificationSocketServiceProvider)
                .events
                .firstWhere(
                  (event) =>
                      event.activityId == activityId && event.groupId != null,
                  orElse: () => const NotificationEvent(event: 'timeout'),
                )
                .timeout(
                  const Duration(seconds: 4),
                  onTimeout: () => const NotificationEvent(event: 'timeout'),
                );
      final acceptedRequest = await ref
          .read(joinRequestsRepositoryProvider)
          .acceptJoinRequest(widget.request.id);
      ref.invalidate(myGroupsProvider);
      widget.onHandled();

      final groupId =
          acceptedRequest.groupId ??
          (groupEventFuture == null ? null : (await groupEventFuture).groupId);
      if (groupId != null && mounted) {
        if (activityId != null) {
          ref
              .read(activityGroupLinksProvider.notifier)
              .recordGroupLink(
                activityId,
                groupId,
                acceptedRequest.activityTitle ?? widget.request.activityTitle,
              );
        }
        context.push('/group/$groupId/chat');
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

  /// NEW: accept only the applicants the host selected from a group request.
  Future<void> _acceptSelectedApplicants(int? spots) async {
    if (_selectedApplicants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one person to accept.')),
      );
      return;
    }
    if (spots != null && _selectedApplicants.length > spots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $spots spot${spots == 1 ? '' : 's'} left. '
            'Deselect ${_selectedApplicants.length - spots} to continue.',
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final activityId = widget.request.activityPostId;
      final groupId = await ref
          .read(groupApplicationsRepositoryProvider)
          .acceptSelected(
            requestId: widget.request.id,
            memberIds: _selectedApplicants.toList(),
          );
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupApplicationProvider(widget.request.id));
      if (activityId != null)
        ref.invalidate(spotsRemainingProvider(activityId));
      widget.onHandled();

      if (groupId != null && mounted) {
        if (activityId != null) {
          ref
              .read(activityGroupLinksProvider.notifier)
              .recordGroupLink(
                activityId,
                groupId,
                widget.request.activityTitle,
              );
        }
        context.push('/group/$groupId/chat');
      }
    } catch (e) {
      // Stale or invalid selection (400): keep the selection open and
      // refresh capacity so the host can adjust.
      final activityId = widget.request.activityPostId;
      if (activityId != null)
        ref.invalidate(spotsRemainingProvider(activityId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
      }
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

  void _toggleApplicant(String id) {
    setState(() {
      if (!_selectedApplicants.remove(id)) _selectedApplicants.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final isPending = r.status == 'pending';

    // NEW: is this a social-group application? (null = individual request)
    final groupAsync = ref.watch(groupApplicationProvider(r.id));
    final groupApp = groupAsync.value;
    final activityId = r.activityPostId;
    final spotsAsync = activityId == null
        ? null
        : ref.watch(spotsRemainingProvider(activityId));
    final spots = spotsAsync?.value;
    final spotsReady = spotsAsync == null || !spotsAsync.isLoading;

    // Pre-select pending applicants up to the spots left, once.
    if (groupApp != null && spotsReady && !_selectionInitialized) {
      final pending = groupApp.applicants.where((a) => a.isPending).toList();
      final take = spots == null
          ? pending.length
          : spots.clamp(0, pending.length);
      _selectedApplicants.addAll(pending.take(take).map((a) => a.id));
      _selectionInitialized = true;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SketchBox(
        seed: r.id.hashCode,
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SketchBox(
                  seed: r.requester?.id.hashCode ?? r.id.hashCode + 1,
                  radius: 13,
                  width: 46,
                  height: 46,
                  child: Center(
                    child: UserAvatar(
                      avatarUrl: r.requester?.avatar,
                      radius: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.requester?.fullName.isNotEmpty == true
                            ? r.requester!.fullName
                            : 'Requester',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (r.activityTitle?.isNotEmpty == true)
                        Text(
                          'For ${r.activityTitle}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: SketchColors.inkFaint),
                        ),
                    ],
                  ),
                ),
                SketchBox(
                  seed: r.status.hashCode,
                  radius: 12,
                  fill: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    _statusLabel(r.status),
                    style: TextStyle(
                      color: isPending
                          ? SketchColors.ink
                          : SketchColors.inkFaint,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (r.requester != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SketchIcon('social_table', size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Trust: ${r.requester!.trustTier} · ${r.requester!.verificationStatus}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SketchColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (r.message?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              SketchBox(
                seed: r.id.hashCode + 2,
                radius: 12,
                fill: null,
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SketchIcon('chat', size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.message!)),
                  ],
                ),
              ),
            ],
            // NEW: group applicants (selectable while pending, read-only after).
            if (groupApp != null) ...[
              const SizedBox(height: 12),
              GroupApplicantsPicker(
                application: groupApp,
                spotsRemaining: spots,
                selected: _selectedApplicants,
                readOnly: !isPending,
                onToggle: _toggleApplicant,
              ),
            ],
            if (r.requester != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _viewRequesterProfile,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('View requester profile'),
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SketchButton(
                      label: 'Decline',
                      onPressed: _isProcessing ? null : _decline,
                      danger: true,
                      seed: r.id.hashCode + 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SketchButton(
                      label: groupApp != null
                          ? 'Accept (${_selectedApplicants.length})'
                          : 'Accept',
                      // Wait until we know if this is a group request so a
                      // group application is never accepted without a selection.
                      onPressed: (_isProcessing || groupAsync.isLoading)
                          ? null
                          : groupApp != null
                          ? () => _acceptSelectedApplicants(spots)
                          : _accept,
                      isLoading: _isProcessing,
                      filled: true,
                      seed: r.id.hashCode + 4,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'pending' => 'Pending',
    'accepted' => 'Accepted',
    'declined' => 'Declined',
    'rejected' => 'Rejected',
    'withdrawn' => 'Withdrawn',
    _ => status,
  };

  void _viewRequesterProfile() {
    final requester = widget.request.requester;
    if (requester == null) return;
    final activityId = widget.request.activityPostId;
    final activityQuery = activityId == null ? '' : '?activityId=$activityId';
    context.push(
      '/profile/${requester.id}/public$activityQuery',
      extra: requester,
    );
  }
}
