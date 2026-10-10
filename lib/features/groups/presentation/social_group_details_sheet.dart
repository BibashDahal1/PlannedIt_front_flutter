import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../data/social_groups_providers.dart';
import '../domain/social_group.dart';
import 'add_social_group_members_sheet.dart';
import 'social_group_member_tile.dart';

/// Group details shown from the bottom (same style as the category picker),
/// so list screens and the chat stay uncluttered. Members and invitations
/// update live; the admin also gets add / remove / delete here.
///
/// Completes with `true` if the group was deleted from this sheet.
class SocialGroupDetailsSheet extends ConsumerWidget {
  final String groupId;

  /// Hide the "Open chat" button when launched from the chat itself.
  final bool showOpenChat;

  const SocialGroupDetailsSheet({
    super.key,
    required this.groupId,
    this.showOpenChat = true,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String groupId,
    bool showOpenChat = true,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: SketchColors.paper,
      builder: (_) =>
          SocialGroupDetailsSheet(groupId: groupId, showOpenChat: showOpenChat),
    );
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    SocialGroup group,
    SocialGroupMember member,
  ) async {
    final name = member.fullName.isNotEmpty ? member.fullName : 'this person';
    final ok = await _confirm(
      context,
      title: 'Remove $name?',
      body: 'They will lose access to this group and its chat.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await ref
          .read(socialGroupsRepositoryProvider)
          .removeMember(group.id, member.id);
      ref.invalidate(mySocialGroupsProvider);
      _snack(context, 'Removed $name.');
    } catch (e) {
      _snack(context, extractApiErrorMessage(e));
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    SocialGroup group,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Delete "${group.name}"?',
      body:
          'This deletes the group and its chat for everyone. '
          'This cannot be undone.',
      confirmLabel: 'Delete group',
    );
    if (!ok) return;
    try {
      await ref.read(socialGroupsRepositoryProvider).deleteGroup(group.id);
      ref.invalidate(mySocialGroupsProvider);
      if (context.mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack(context, extractApiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final groupsAsync = ref.watch(mySocialGroupsProvider);
    final theme = Theme.of(context);

    final groups = groupsAsync.value;
    SocialGroup? group;
    if (groups != null) {
      for (final g in groups) {
        if (g.id == groupId) group = g;
      }
    }

    // Loading for the first time.
    if (group == null && groups == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // The group is gone (deleted, or this person was removed): close.
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox(height: 160);
    }

    final g = group;
    final used = g.memberCount + g.pendingInvitations.length;
    final isFull = used >= 10;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            // ---------- Header ----------
            Row(
              children: [
                SketchBox(
                  seed: g.id.hashCode + 1,
                  radius: 14,
                  width: 54,
                  height: 54,
                  child: const Center(
                    child: SketchIcon('dashboard_groups', size: 36),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${g.memberCount} members'
                        '${g.isAdmin ? ' · You are admin' : ''}',
                        style: TextStyle(color: SketchColors.inkFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (showOpenChat) ...[
              SketchButton(
                label: g.canChat
                    ? 'Open chat'
                    : 'Chat opens when someone accepts',
                icon: const Icon(Icons.chat_bubble_outline),
                filled: true,
                onPressed: g.canChat
                    ? () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/social-group/${g.id}/chat');
                      }
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            // ---------- Members ----------
            Text(
              'Members (${g.memberCount})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final m in g.members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SocialGroupMemberTile(
                  member: m,
                  onRemove: g.isAdmin && !m.isAdmin
                      ? () => _removeMember(context, ref, g, m)
                      : null,
                ),
              ),

            // ---------- Invited, not answered yet (admin only) ----------
            if (g.pendingInvitations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Invited (${g.pendingInvitations.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final p in g.pendingInvitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PendingInviteRow(groupId: g.id, invite: p),
                ),
            ],

            // ---------- Admin actions ----------
            if (g.isAdmin) ...[
              const SizedBox(height: 12),
              SketchButton(
                label: isFull ? 'Group is full' : 'Add members',
                icon: const Icon(Icons.group_add),
                onPressed: isFull
                    ? null
                    : () async {
                        final sent = await AddSocialGroupMembersSheet.show(
                          context,
                          g,
                        );
                        if (sent == true) {
                          ref.invalidate(mySocialGroupsProvider);
                          _snack(context, 'Invitations sent.');
                        }
                      },
              ),
              const SizedBox(height: 10),
              SketchButton(
                label: 'Delete group',
                icon: const Icon(Icons.delete_outline),
                danger: true,
                onPressed: () => _deleteGroup(context, ref, g),
              ),
            ],
          ],
        ),
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
