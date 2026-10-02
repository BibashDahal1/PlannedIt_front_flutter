import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_providers.dart';
import '../../../core/widgets/sketch_icon.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(activityGroupLinksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: links.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No chats yet. Once you\'re accepted into an activity, '
                  'or accept someone into yours, the group chat will appear here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: links.entries
                  .map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const SketchIcon('chat', size: 24),
                        title: Text(entry.value.activityTitle),
                        subtitle: const Text('Tap to open group chat'),
                        onTap: () =>
                            context.push('/group/${entry.value.groupId}/chat'),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
