import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_event.dart';
import '../../../core/realtime/notification_inbox_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationInboxProvider.notifier).openInbox();
    });
  }

  @override
  void dispose() {
    ref.read(notificationInboxProvider.notifier).closeInbox();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationInboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: inbox.unreadNotificationCount == 0
                ? null
                : () => ref
                      .read(notificationInboxProvider.notifier)
                      .markAllRead(),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: inbox.items.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView.separated(
              itemCount: inbox.items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = inbox.items[index];
                return ListTile(
                  leading: Icon(_iconFor(item.event.event)),
                  title: Text(
                    item.event.displayMessage,
                    style: TextStyle(
                      fontWeight: item.isRead
                          ? FontWeight.normal
                          : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    item.event.activityTitle ??
                        item.event.event.replaceAll('_', ' '),
                  ),
                  trailing: item.isRead
                      ? null
                      : const Icon(Icons.circle, size: 9),
                  onTap: _onNotificationTap(item.id, item.event),
                );
              },
            ),
    );
  }

  VoidCallback? _onNotificationTap(
    String notificationId,
    NotificationEvent event,
  ) {
    final canOpenGroup =
        event.groupId != null &&
        (event.event == 'new_chat_message' ||
            event.event == 'request_accepted' ||
            event.event == 'roster_updated');
    final canOpenActivity =
        event.activityId != null && event.event != 'activity_deleted';
    if (!canOpenGroup && !canOpenActivity) return null;

    return () {
      ref
          .read(notificationInboxProvider.notifier)
          .markNotificationRead(notificationId);
      if (canOpenGroup) {
        ref
            .read(notificationInboxProvider.notifier)
            .markGroupRead(event.groupId!);
        context.push('/group/${event.groupId}/chat');
      } else if (event.event == 'new_join_request') {
        context.push('/activity/${event.activityId}/requests');
      } else {
        context.push('/activity/${event.activityId}');
      }
    };
  }

  IconData _iconFor(String event) {
    switch (event) {
      case 'new_chat_message':
        return Icons.chat_bubble_outline;
      case 'new_join_request':
        return Icons.person_add_alt_1;
      case 'request_accepted':
        return Icons.check_circle_outline;
      case 'request_declined':
        return Icons.cancel_outlined;
      case 'activity_deleted':
      case 'activity_cancelled':
        return Icons.event_busy_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}
