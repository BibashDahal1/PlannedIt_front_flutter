import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/realtime/notification_inbox_provider.dart';
import '../../groups/data/groups_providers.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
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
      backgroundColor: Colors.transparent,
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
        loading: () => Center(
          child: SketchBox(
            radius: 18,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: SketchColors.ink,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 12),
                const Text('Loading your group chats...'),
              ],
            ),
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SketchBox(
              radius: 18,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SketchIcon('chat', size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load chats. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SketchButton(
                    label: 'Retry',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(myGroupsProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (groups) => groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SketchBox(
                    radius: 18,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SketchIcon('chat', size: 42),
                        const SizedBox(height: 12),
                        Text(
                          'No chats yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Once you join a group, its chat will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: SketchColors.inkFaint),
                        ),
                      ],
                    ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SketchBox(
                      seed: index + 100,
                      radius: 18,
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              context.push('/group/${group.id}/chat'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Badge(
                                  isLabelVisible: unreadCount > 0,
                                  label: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                  ),
                                  child: const SketchIcon('chat', size: 34),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.activityTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        memberPreview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: SketchColors.inkFaint,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: SketchColors.inkFaint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
