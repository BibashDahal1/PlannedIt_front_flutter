import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../data/groups_providers.dart';
import '../data/social_groups_providers.dart';
import '../domain/social_group.dart';
import 'create_social_group_sheet.dart';
import 'social_group_invitations_tab.dart';
import 'social_group_member_tile.dart';

/// Two tabs:
///  - "Group chats": groups you create yourself from people you've met.
///  - "Activity groups": groups created when a join request is accepted.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        // Rebuild when the selected tab changes so the FAB can show/hide.
        if (!_tabController.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Opens the "create a group" form (name + pick people you've met).
  Future<void> _createGroup() async {
    final created = await CreateSocialGroupSheet.show(context);
    if (created == true) {
      ref.invalidate(mySocialGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created. Invitations sent.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh groups',
            onPressed: () {
              ref.invalidate(myGroupsProvider);
              ref.invalidate(mySocialGroupsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Group chats'),
            Tab(text: 'Activity groups'),
          ],
        ),
      ),
      // Only relevant to the "Group chats" tab.
      floatingActionButton: _tabController.index == 0
          ? _CreateGroupButton(onPressed: _createGroup)
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _GroupChatsTab(onCreate: _createGroup),
          const _ActivityGroupsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Group chats (social groups)
// ---------------------------------------------------------------------------
class _GroupChatsTab extends ConsumerWidget {
  final VoidCallback onCreate;
  const _GroupChatsTab({required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(socialGroupLiveRefreshProvider);
    final socialAsync = ref.watch(mySocialGroupsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(socialGroupInvitationsProvider);
        ref.invalidate(mySocialGroupsProvider);
        try {
          await ref.read(mySocialGroupsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Invitations to other people's groups appear first.
          const SocialGroupInvitationsSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Groups you create with people you have joined activities with.',
              style: TextStyle(color: SketchColors.inkFaint),
            ),
          ),
          socialAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _MessageBox(
              message:
                  'Could not load groups: ${extractApiErrorMessage(error)}',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(mySocialGroupsProvider),
            ),
            data: (groups) => groups.isEmpty
                ? _MessageBox(
                    message: 'You have no groups yet.',
                    actionLabel: 'Create a group',
                    onAction: onCreate,
                  )
                : Column(
                    children: [
                      for (final g in groups) _SocialGroupTile(group: g),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Activity groups (existing accepted-activity rosters)
// ---------------------------------------------------------------------------
class _ActivityGroupsTab extends ConsumerWidget {
  const _ActivityGroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myGroupsProvider);
        try {
          await ref.read(myGroupsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Activity groups are created from activities after a join request is accepted.',
              style: TextStyle(color: SketchColors.inkFaint),
            ),
          ),
          groupsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _MessageBox(
              message:
                  'Could not load groups: ${extractApiErrorMessage(error)}',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(myGroupsProvider),
            ),
            data: (groups) => groups.isEmpty
                ? _MessageBox(
                    message: 'Your activity groups will appear here',
                    actionLabel: 'Post an activity',
                    onAction: () => context.go('/post-activity'),
                  )
                : Column(
                    children: [
                      for (final group in groups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SketchBox(
                            seed: group.id.hashCode,
                            radius: 18,
                            padding: EdgeInsets.zero,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    context.push('/group/${group.id}/chat'),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const SketchIcon(
                                        'dashboard_groups',
                                        size: 40,
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
                                              '${group.memberCount} members',
                                              style: TextStyle(
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
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Floating "Create a group" button drawn in the sketch style.
/// Black box with white content in light mode, white box with black content
/// in dark mode (follows SketchColors.ink).
class _CreateGroupButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const _CreateGroupButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when the theme is toggled so SketchColors.ink is re-read.
    ref.watch(themeModeProvider);

    final fill = SketchColors.ink;
    // Pick a contrasting foreground from the fill's brightness.
    final foreground = fill.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return Semantics(
      button: true,
      label: 'Create a group',
      child: SketchBox(
        seed: 77,
        radius: 16,
        fill: fill,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_add, color: foreground),
                  const SizedBox(width: 10),
                  Text(
                    'Create a group',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Social group card. Tap to expand and see the roster.
class _SocialGroupTile extends StatefulWidget {
  final SocialGroup group;
  const _SocialGroupTile({required this.group});

  @override
  State<_SocialGroupTile> createState() => _SocialGroupTileState();
}

class _SocialGroupTileState extends State<_SocialGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SketchBox(
        seed: group.id.hashCode,
        radius: 18,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SketchIcon('dashboard_groups', size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${group.memberCount} members'
                              '${group.isAdmin ? ' · You are admin' : ''}',
                              style: TextStyle(color: SketchColors.inkFaint),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: SketchColors.inkFaint,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 12),
                    for (final m in group.members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SocialGroupMemberTile(member: m),
                      ),
                    for (final p in group.pendingInvitations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PendingInviteRow(groupId: group.id, invite: p),
                      ),
                    const SizedBox(height: 4),
                    SketchButton(
                      label: group.canChat
                          ? 'Open chat'
                          : 'Chat opens when someone accepts',
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: group.canChat
                          ? () => context.push('/social-group/${group.id}/chat')
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageBox({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      radius: 18,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SketchButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}

/// An invited person who has not answered yet (visible to the admin only).
class _PendingInviteRow extends ConsumerWidget {
  final String groupId;
  final SocialGroupPendingInvite invite;
  const _PendingInviteRow({required this.groupId, required this.invite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SketchBox(
      seed: invite.id.hashCode,
      radius: 14,
      fill: null,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 20, color: SketchColors.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              invite.fullName.isNotEmpty ? invite.fullName : 'Invited person',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: SketchColors.inkFaint,
              ),
            ),
          ),
          Text(
            'Invited',
            style: TextStyle(fontSize: 11, color: SketchColors.inkFaint),
          ),
          IconButton(
            tooltip: 'Cancel invitation',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () async {
              try {
                await ref
                    .read(socialGroupsRepositoryProvider)
                    .cancelInvitation(groupId, invite.id);
                ref.invalidate(mySocialGroupsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(extractApiErrorMessage(e))),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
