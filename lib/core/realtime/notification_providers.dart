import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/activities/data/activities_providers.dart';
import '../../features/groups/data/groups_providers.dart';
import '../../features/join_requests/data/join_requests_providers.dart';
import 'activity_group_link.dart';
import 'notification_event.dart';
import 'notification_socket_service.dart';

final notificationSocketServiceProvider = Provider<NotificationSocketService>((
  ref,
) {
  final service = NotificationSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Broadcasts every parsed event as it arrives -- screens `ref.listen`
/// to this for toasts/refreshes without owning the socket themselves.
final notificationEventsProvider = StreamProvider<NotificationEvent>((ref) {
  return ref.watch(notificationSocketServiceProvider).events;
});

/// Learned activityId -> group links, persisted so they survive app
/// restarts. Populated whenever a `request_accepted`/`roster_updated`
/// event carries a group_id.
///
/// Only `request_accepted` (requester-side) includes `activity_title`;
/// `roster_updated` (which is what a HOST receives when their own
/// activity gets a new member) does not. So for hosts, the title is
/// resolved separately via GET /activities/{id} the first time a link
/// is learned without one, and the cache is updated once that
/// resolves -- rather than permanently showing a generic placeholder
/// for every one of a host's chats.
class ActivityGroupLinks extends Notifier<Map<String, ActivityGroupLink>> {
  static const _storageKey = 'activity_group_links';

  @override
  Map<String, ActivityGroupLink> build() {
    _loadFromStorage();
    ref.listen(notificationEventsProvider, (previous, next) {
      next.whenData((event) {
        if (event.groupId != null && event.activityId != null) {
          _add(event.activityId!, event.groupId!, event.activityTitle);
        }
        switch (event.event) {
          case 'activity_cancelled':
            ref.invalidate(myActivitiesProvider);
            ref.invalidate(activityFeedProvider(null));
            if (event.activityId != null) {
              ref.invalidate(activityDetailProvider(event.activityId!));
            }
            break;
          case 'new_join_request':
            if (event.activityId != null) {
              ref.invalidate(incomingRequestsProvider(event.activityId!));
            }
            break;
          case 'request_accepted':
            ref.invalidate(myGroupsProvider);
            ref.invalidate(myJoinRequestsProvider);
            if (event.activityId != null) {
              ref.invalidate(activityDetailProvider(event.activityId!));
            }
            break;
          case 'request_declined':
            ref.invalidate(myJoinRequestsProvider);
            if (event.activityId != null) {
              ref.invalidate(activityDetailProvider(event.activityId!));
            }
            break;
          case 'roster_updated':
            ref.invalidate(myGroupsProvider);
            ref.invalidate(myActivitiesProvider);
            break;
          case 'teams_updated':
            ref.invalidate(myGroupsProvider);
            if (event.groupId != null) {
              ref.invalidate(groupRosterProvider(event.groupId!));
            }
            break;
          case 'expense_added':
          case 'expense_updated':
          case 'expense_deleted':
            if (event.groupId != null) {
              ref.invalidate(groupRosterProvider(event.groupId!));
              ref.invalidate(groupExpensesProvider(event.groupId!));
            }
            break;
          case 'activity_deleted':
            ref.invalidate(myGroupsProvider);
            ref.invalidate(myActivitiesProvider);
            ref.invalidate(myJoinRequestsProvider);
            ref.invalidate(activityFeedProvider(null));
            if (event.activityId != null) {
              // The activity is genuinely gone -- drop its cached group link too,
              // so a stale "Open Group Chat" button can't appear for it later.
              final updated = Map<String, ActivityGroupLink>.from(state)
                ..remove(event.activityId);
              if (updated.length != state.length) {
                state = updated;
                _persist();
              }
            }
            break;
        }
      });
    });
    ref.listen(myJoinRequestsProvider, (previous, next) {
      next.whenData((requests) {
        for (final request in requests) {
          if (request.status == 'accepted' &&
              request.activityPostId != null &&
              request.groupId != null) {
            _add(
              request.activityPostId!,
              request.groupId!,
              request.activityTitle,
            );
          }
        }
      });
    });
    return {};
  }

  Future<void> _loadFromStorage() async {
    try {
      final storage = ref.read(tokenStorageProvider);
      final raw = await storage.readRaw(_storageKey);
      if (raw == null) return;
      final decoded = (jsonDecode(raw) as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          ActivityGroupLink.fromJson(value as Map<String, dynamic>),
        ),
      );
      state = {...decoded, ...state};
    } catch (_) {
      // No stored links yet -- starts empty, which is fine.
    }
  }

  void _add(String activityId, String groupId, String? incomingTitle) {
    final existing = state[activityId];
    // Prefer a real title we already have (from a previous event or a
    // completed lookup) over overwriting it with another unnamed event.
    final resolvedTitle = incomingTitle ?? existing?.activityTitle;

    final alreadyUpToDate =
        existing?.groupId == groupId &&
        existing?.activityTitle == resolvedTitle;
    if (alreadyUpToDate) return;

    final link = ActivityGroupLink(
      groupId: groupId,
      activityTitle: resolvedTitle ?? 'Activity',
    );
    state = {...state, activityId: link};
    _persist();

    // No real title yet (this was a roster_updated with nothing to go
    // on) -- fetch it once in the background and patch the cache.
    if (resolvedTitle == null) {
      _resolveTitleInBackground(activityId, groupId);
    }
  }

  void recordGroupLink(
    String activityId,
    String groupId,
    String? activityTitle,
  ) => _add(activityId, groupId, activityTitle);

  Future<void> _resolveTitleInBackground(
    String activityId,
    String groupId,
  ) async {
    try {
      final activity = await ref
          .read(activitiesRepositoryProvider)
          .fetchActivityDetail(activityId);
      final current = state[activityId];
      // Only patch if this link is still pointing at the same group --
      // avoids clobbering a newer state if things changed while the
      // request was in flight.
      if (current != null && current.groupId == groupId) {
        state = {
          ...state,
          activityId: ActivityGroupLink(
            groupId: groupId,
            activityTitle: activity.title,
          ),
        };
        _persist();
      }
    } catch (_) {
      // Leave the 'Activity' placeholder in place if this fails --
      // not worth surfacing an error for a cosmetic label.
    }
  }

  void _persist() {
    final encoded = jsonEncode(
      state.map((key, value) => MapEntry(key, value.toJson())),
    );
    ref.read(tokenStorageProvider).writeRaw(_storageKey, encoded);
  }
}

final activityGroupLinksProvider =
    NotifierProvider<ActivityGroupLinks, Map<String, ActivityGroupLink>>(
      ActivityGroupLinks.new,
    );

/// Keeps the notifications socket connected while logged in, and
/// cleanly disconnected on logout. Instantiated once near the app root.
class NotificationConnectionManager extends Notifier<void> {
  @override
  void build() {
    ref.listen(authControllerProvider, (previous, next) {
      next.whenData((authState) async {
        final service = ref.read(notificationSocketServiceProvider);
        if (authState.isLoggedIn) {
          final token = await ref.read(tokenStorageProvider).accessToken;
          if (token != null) service.connect(token);
        } else {
          service.disconnect();
        }
      });
    });
  }
}

final notificationConnectionManagerProvider =
    NotifierProvider<NotificationConnectionManager, void>(
      NotificationConnectionManager.new,
    );
