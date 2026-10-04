import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/notification_inbox_provider.dart';
import '../realtime/notification_providers.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Wraps the whole app; keeps the notification socket connection
/// manager alive for the app's full lifetime (not tied to any one
/// screen), and shows a snackbar toast for any event that arrives.
class AppNotificationsGate extends ConsumerWidget {
  final Widget child;
  const AppNotificationsGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationConnectionManagerProvider);
    ref.listen(notificationInboxProvider, (previous, next) {});
    ref.listen(notificationEventsProvider, (previous, next) {
      next.whenData((event) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(event.displayMessage)),
        );
      });
    });
    return child;
  }
}
