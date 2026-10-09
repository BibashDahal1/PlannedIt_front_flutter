import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/realtime/notification_inbox_provider.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../groups/data/groups_providers.dart';
import '../../groups/data/social_groups_providers.dart';
import '../../groups/domain/social_group.dart';

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final groupsAsync = ref.watch(myGroupsProvider);
    final unreadMessagesByGroup = ref
        .watch(notificationInboxProvider)
        .unreadMessagesByGroup;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Chats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(myGroupsProvider);
                ref.invalidate(mySocialGroupsProvider);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activity Chats'),
              Tab(text: 'Group Chats'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ---------------- Activity chats (unchanged) ----------------
            groupsAsync.when(
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
                      const Text('Loading activity chats...'),
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
                          'Could not load activity chats. Please try again.',
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
                                'No activity chats yet',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Activity chats appear after a join request is accepted and its group is created.',
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
                        final unreadCount =
                            unreadMessagesByGroup[group.id] ?? 0;
                        final memberNames =
                            group.memberNames ?? const <String>[];
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
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                        ),
                                        child: const SketchIcon(
                                          'chat',
                                          size: 34,
                                        ),
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
                                                    color:
                                                        SketchColors.inkFaint,
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

            // ---------------- Group chats (social groups) ----------------
            const _SocialGroupChatsTab(),
          ],
        ),
      ),
    );
  }
}

/// Lists the user's social groups from GET /social-groups/mine.
class _SocialGroupChatsTab extends ConsumerWidget {
  const _SocialGroupChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialAsync = ref.watch(mySocialGroupsProvider);

    return socialAsync.when(
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
              const Text('Loading group chats...'),
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
                Text(
                  'Could not load group chats: ${extractApiErrorMessage(error)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SketchButton(
                  label: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(mySocialGroupsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (groups) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySocialGroupsProvider);
          try {
            await ref.read(mySocialGroupsProvider.future);
          } catch (_) {}
        },
        child: groups.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  SketchBox(
                    radius: 18,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SketchIcon('chat', size: 42),
                        const SizedBox(height: 12),
                        Text(
                          'No group chats yet',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a group from your dashboard to see it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: SketchColors.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _SocialGroupChatTile(group: group, index: index);
                },
              ),
      ),
    );
  }
}

class _SocialGroupChatTile extends StatelessWidget {
  final SocialGroup group;
  final int index;
  const _SocialGroupChatTile({required this.group, required this.index});

  String get _memberPreview {
    final names = group.members
        .map((m) => m.fullName)
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isEmpty) return '${group.memberCount} members';
    return names.take(3).join(', ') +
        (names.length > 3 ? ' +${names.length - 3}' : '');
  }

  @override
  Widget build(BuildContext context) {
    final seed = group.id.hashCode + index;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SketchBox(
        seed: seed,
        radius: 18,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showMembers(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Icon in its own sketch box, like the dashboard group picker.
                  SketchBox(
                    seed: seed + 1,
                    radius: 14,
                    width: 54,
                    height: 54,
                    child: const Center(child: SketchIcon('chat', size: 36)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _AvatarStack(members: group.members),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${group.memberCount} members',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: SketchColors.inkFaint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _memberPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SketchColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (group.isAdmin) ...[
                        _RolePill(seed: seed + 2, label: 'Admin'),
                        const SizedBox(height: 6),
                      ],
                      Icon(Icons.chevron_right, color: SketchColors.inkFaint),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// TODO: replace with navigation to a social group chat screen once the
  /// social chat API/socket service exists. For now, show the roster.
  void _showMembers(BuildContext context) {
    final seed = group.id.hashCode;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SketchBox(
                      seed: seed + 1,
                      radius: 14,
                      width: 54,
                      height: 54,
                      child: const Center(child: SketchIcon('chat', size: 36)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${group.memberCount} members',
                            style: TextStyle(color: SketchColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = group.members[i];
                      return SketchBox(
                        seed: m.id.hashCode,
                        radius: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            UserAvatar(avatarUrl: m.avatar, radius: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                m.fullName.isNotEmpty
                                    ? m.fullName
                                    : 'Unknown member',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (m.isAdmin)
                              _RolePill(
                                seed: m.id.hashCode + 1,
                                label: 'Admin',
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three overlapping member avatars with an ink ring.
class _AvatarStack extends StatelessWidget {
  final List<SocialGroupMember> members;
  const _AvatarStack({required this.members});

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const radius = 11.0;
    const step = 16.0;
    return SizedBox(
      width: step * (shown.length - 1) + radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SketchColors.paper,
                  border: Border.all(color: SketchColors.ink, width: 1.2),
                ),
                child: UserAvatar(avatarUrl: shown[i].avatar, radius: radius),
              ),
            ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final int seed;
  final String label;
  const _RolePill({required this.seed, required this.label});

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: seed,
      radius: 10,
      fill: null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
