import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/social_groups_providers.dart';
import '../domain/social_group.dart';

/// Pending invitations to join someone's social group. A person only becomes
/// a member (and can use the group chat) after accepting here.
class SocialGroupInvitationsTab extends ConsumerWidget {
  const SocialGroupInvitationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(socialGroupInvitationsProvider);

    return invitesAsync.when(
      loading: () => Center(
        child: SketchBox(
          radius: 16,
          padding: const EdgeInsets.all(20),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading invitations...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SketchBox(
            radius: 16,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load invitations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  extractApiErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SketchColors.inkFaint),
                ),
                const SizedBox(height: 12),
                SketchButton(
                  label: 'Try again',
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.invalidate(socialGroupInvitationsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (invites) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(socialGroupInvitationsProvider);
          try {
            await ref.read(socialGroupInvitationsProvider.future);
          } catch (_) {}
        },
        child: invites.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  SketchBox(
                    radius: 18,
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SketchIcon('people', size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No group invitations.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'When someone invites you to a group, it will appear here.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: invites.length,
                itemBuilder: (context, i) =>
                    SocialGroupInvitationCard(invitation: invites[i]),
              ),
      ),
    );
  }
}

class SocialGroupInvitationCard extends ConsumerStatefulWidget {
  final SocialGroupInvitation invitation;
  const SocialGroupInvitationCard({super.key, required this.invitation});

  @override
  ConsumerState<SocialGroupInvitationCard> createState() =>
      _SocialGroupInvitationCardState();
}

class _SocialGroupInvitationCardState
    extends ConsumerState<SocialGroupInvitationCard> {
  bool _processing = false;

  Future<void> _respond({required bool accept}) async {
    if (_processing) return;
    setState(() => _processing = true);
    final repo = ref.read(socialGroupsRepositoryProvider);
    final name = widget.invitation.groupName;
    try {
      if (accept) {
        await repo.acceptInvitation(widget.invitation.id);
      } else {
        await repo.declineInvitation(widget.invitation.id);
      }
      ref.invalidate(socialGroupInvitationsProvider);
      ref.invalidate(mySocialGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'You joined "$name". You can chat now.'
                  : 'Invitation declined.',
            ),
          ),
        );
      }
    } catch (e) {
      // Stale invitation (cancelled / group full): refresh so it disappears.
      ref.invalidate(socialGroupInvitationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invitation;
    final seed = inv.id.hashCode;
    final theme = Theme.of(context);
    final inviter = inv.invitedByName.isNotEmpty
        ? inv.invitedByName
        : 'Someone';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SketchBox(
        seed: seed,
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SketchBox(
                  seed: seed + 1,
                  radius: 13,
                  width: 46,
                  height: 46,
                  child: Center(
                    child: UserAvatar(
                      avatarUrl: inv.invitedByAvatar,
                      radius: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.groupName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$inviter invited you to join this group',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: SketchColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                SketchBox(
                  seed: seed + 2,
                  radius: 12,
                  fill: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SketchIcon('people', size: 18),
                const SizedBox(width: 6),
                Text(
                  '${inv.groupMemberCount} '
                  '${inv.groupMemberCount == 1 ? 'member' : 'members'} so far',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SketchColors.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SketchButton(
                    label: 'Decline',
                    onPressed: _processing
                        ? null
                        : () => _respond(accept: false),
                    danger: true,
                    seed: seed + 3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SketchButton(
                    label: 'Accept',
                    onPressed: _processing
                        ? null
                        : () => _respond(accept: true),
                    isLoading: _processing,
                    filled: true,
                    seed: seed + 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact block of pending invitations. Renders nothing when there are none,
/// so it can sit at the top of any list (Groups and Chats "Group chats" tabs).
class SocialGroupInvitationsSection extends ConsumerWidget {
  const SocialGroupInvitationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(socialGroupInvitationsProvider).value ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              const SketchIcon('people', size: 22),
              const SizedBox(width: 8),
              Text(
                'Group invitations (${invites.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        for (final invite in invites)
          SocialGroupInvitationCard(invitation: invite),
        const SizedBox(height: 6),
      ],
    );
  }
}
