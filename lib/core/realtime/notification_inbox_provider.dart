import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'notification_event.dart';
import 'notification_providers.dart';

class NotificationInboxItem {
  final String id;
  final NotificationEvent event;
  final DateTime receivedAt;
  final bool isRead;

  const NotificationInboxItem({
    required this.id,
    required this.event,
    required this.receivedAt,
    required this.isRead,
  });

  NotificationInboxItem copyWith({bool? isRead}) => NotificationInboxItem(
    id: id,
    event: event,
    receivedAt: receivedAt,
    isRead: isRead ?? this.isRead,
  );
}

class NotificationInboxState {
  final List<NotificationInboxItem> items;
  final Map<String, int> unreadMessagesByGroup;

  const NotificationInboxState({
    this.items = const [],
    this.unreadMessagesByGroup = const {},
  });

  int get unreadNotificationCount => items.where((item) => !item.isRead).length;

  int get unreadChatMessageCount =>
      unreadMessagesByGroup.values.fold(0, (total, count) => total + count);

  int unreadCountForGroup(String groupId) =>
      unreadMessagesByGroup[groupId] ?? 0;
}

class NotificationInbox extends Notifier<NotificationInboxState> {
  static const _maxItems = 100;
  static const _maxSeenIds = 500;

  final Set<String> _seenIds = {};
  bool _isInboxOpen = false;
  String? _activeChatGroupId;

  @override
  NotificationInboxState build() {
    ref.listen(notificationEventsProvider, (previous, next) {
      next.whenData(_receive);
    });
    ref.listen(authControllerProvider, (previous, next) {
      next.whenData((authState) {
        if (!authState.isLoggedIn) _clear();
      });
    });
    return const NotificationInboxState();
  }

  void _receive(NotificationEvent event) {
    final id = _eventId(event);
    if (!_seenIds.add(id)) return;
    if (_seenIds.length > _maxSeenIds) _seenIds.remove(_seenIds.first);

    final isChatMessage = event.event == 'new_chat_message';
    final isRead =
        _isInboxOpen || (isChatMessage && event.groupId == _activeChatGroupId);
    final unreadByGroup = Map<String, int>.from(state.unreadMessagesByGroup);
    if (isChatMessage &&
        event.groupId != null &&
        event.groupId != _activeChatGroupId) {
      unreadByGroup.update(
        event.groupId!,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final items = [
      NotificationInboxItem(
        id: id,
        event: event,
        receivedAt: DateTime.now(),
        isRead: isRead,
      ),
      ...state.items,
    ];
    state = NotificationInboxState(
      items: items.take(_maxItems).toList(growable: false),
      unreadMessagesByGroup: unreadByGroup,
    );
  }

  String _eventId(NotificationEvent event) {
    final messageId = event.chatMessage?['id']?.toString();
    final stableId = messageId ?? event.joinRequestId;
    if (stableId != null) return '${event.event}:$stableId';
    if ((event.event == 'activity_cancelled' ||
            event.event == 'activity_deleted') &&
        event.activityId != null) {
      return '${event.event}:${event.activityId}';
    }
    return '${event.event}:${DateTime.now().microsecondsSinceEpoch}';
  }

  void openInbox() {
    _isInboxOpen = true;
    markAllRead();
  }

  void closeInbox() => _isInboxOpen = false;

  void markAllRead() {
    if (state.items.every((item) => item.isRead)) return;
    state = NotificationInboxState(
      items: state.items
          .map((item) => item.copyWith(isRead: true))
          .toList(growable: false),
      unreadMessagesByGroup: state.unreadMessagesByGroup,
    );
  }

  void markNotificationRead(String id) {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index == -1 || state.items[index].isRead) return;
    final items = List<NotificationInboxItem>.from(state.items);
    items[index] = items[index].copyWith(isRead: true);
    state = NotificationInboxState(
      items: items,
      unreadMessagesByGroup: state.unreadMessagesByGroup,
    );
  }

  void openChat(String groupId) {
    _activeChatGroupId = groupId;
    markGroupRead(groupId);
  }

  void closeChat(String groupId) {
    if (_activeChatGroupId == groupId) _activeChatGroupId = null;
  }

  void markGroupRead(String groupId) {
    final unreadByGroup = Map<String, int>.from(state.unreadMessagesByGroup)
      ..remove(groupId);
    final hasUnreadNotifications = state.items.any(
      (item) => item.event.groupId == groupId && !item.isRead,
    );
    final items = hasUnreadNotifications
        ? state.items
              .map(
                (item) => item.event.groupId == groupId
                    ? item.copyWith(isRead: true)
                    : item,
              )
              .toList(growable: false)
        : state.items;
    if (unreadByGroup.length == state.unreadMessagesByGroup.length &&
        !hasUnreadNotifications) {
      return;
    }
    state = NotificationInboxState(
      items: items,
      unreadMessagesByGroup: unreadByGroup,
    );
  }

  void _clear() {
    _seenIds.clear();
    _isInboxOpen = false;
    _activeChatGroupId = null;
    state = const NotificationInboxState();
  }
}

final notificationInboxProvider =
    NotifierProvider<NotificationInbox, NotificationInboxState>(
      NotificationInbox.new,
    );
