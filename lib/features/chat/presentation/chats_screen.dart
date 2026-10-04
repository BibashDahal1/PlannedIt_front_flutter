import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_inbox_provider.dart';
import '../../groups/data/groups_providers.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_icon.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider); // forces rebuild on theme toggle
    final groupsAsync = ref.watch(myGroupsProvider);
    final unreadMessagesByGroup = ref
        .watch(notificationInboxProvider)
        .unreadMessagesByGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(myGroupsProvider),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Could not load chats. Tap refresh to try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (groups) => groups.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No chats yet. Once you\'re in a group, it will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final unreadCount = unreadMessagesByGroup[group.id] ?? 0;
                  final memberNames = group.memberNames ?? const <String>[];
                  final memberPreview = memberNames.isEmpty
                      ? '${group.memberCount} members'
                      : memberNames.take(3).join(', ') +
                            (memberNames.length > 3
                                ? ' +${memberNames.length - 3}'
                                : '');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                        child: const SketchIcon('chat', size: 28),
                      ),
                      title: Text(group.activityTitle),
                      subtitle: Text('$memberPreview · Tap to open group chat'),
                      onTap: () => context.push('/group/${group.id}/chat'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
