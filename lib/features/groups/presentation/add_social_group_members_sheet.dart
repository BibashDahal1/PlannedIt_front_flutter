import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../data/social_groups_providers.dart';
import '../domain/social_group.dart';
import 'create_social_group_sheet.dart' show EligibleMemberRow;

/// Admin-only: invite more people to an existing group. Invited people join
/// only after they accept. Pops with `true` if at least one invite was sent.
class AddSocialGroupMembersSheet extends ConsumerStatefulWidget {
  final SocialGroup group;
  const AddSocialGroupMembersSheet({super.key, required this.group});

  static Future<bool?> show(BuildContext context, SocialGroup group) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddSocialGroupMembersSheet(group: group),
    );
  }

  @override
  ConsumerState<AddSocialGroupMembersSheet> createState() =>
      _AddSocialGroupMembersSheetState();
}

class _AddSocialGroupMembersSheetState
    extends ConsumerState<AddSocialGroupMembersSheet> {
  static const _groupLimit = 10; // members + pending invitations

  final Set<String> _selected = {};
  String _query = '';
  bool _submitting = false;
  String? _error;

  int get _capacity {
    final used =
        widget.group.members.length + widget.group.pendingInvitations.length;
    return (_groupLimit - used).clamp(0, _groupLimit);
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id) && _selected.length < _capacity) {
        _selected.add(id);
      }
      _error = null;
    });
  }

  Future<void> _submit(List<EligibleMember> pool) async {
    if (_submitting || _selected.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = ref.read(socialGroupsRepositoryProvider);
    final failures = <String>[];
    var sent = 0;
    for (final id in _selected.toList()) {
      try {
        await repo.inviteMember(widget.group.id, id);
        sent++;
        _selected.remove(id);
      } catch (e) {
        final name = pool.firstWhere(
          (m) => m.id == id,
          orElse: () =>
              EligibleMember(id: id, fullName: 'Someone', trustTier: ''),
        );
        failures.add('${name.fullName}: ${extractApiErrorMessage(e)}');
      }
    }
    if (sent > 0) ref.invalidate(mySocialGroupsProvider);
    if (!mounted) return;
    if (failures.isEmpty) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = failures.join('\n');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final membersAsync = ref.watch(eligibleMembersProvider);
    final theme = Theme.of(context);
    final capacity = _capacity;

    // Hide people already in the group or already invited.
    final taken = <String>{
      ...widget.group.members.map((m) => m.id),
      ...widget.group.pendingInvitations.map((p) => p.userId),
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SketchBox(
                      seed: 801,
                      radius: 14,
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SketchIcon('dashboard_groups', size: 32),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add members',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: SketchColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                    SketchBox(
                      seed: 802,
                      radius: 10,
                      fill: null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        '${_selected.length} / $capacity',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (capacity == 0)
                  SketchBox(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This group is full. A group holds at most 10 people, '
                      'counting pending invitations. Remove a member or cancel '
                      'an invitation to make room.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SketchColors.inkFaint),
                    ),
                  )
                else ...[
                  SketchBox(
                    seed: 803,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: SketchColors.inkFaint),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search people',
                              hintStyle: TextStyle(
                                color: SketchColors.inkFaint,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: (v) =>
                                setState(() => _query = v.trim().toLowerCase()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: membersAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => SketchBox(
                        radius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Could not load people: '
                              '${extractApiErrorMessage(error)}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            SketchButton(
                              label: 'Try again',
                              icon: const Icon(Icons.refresh),
                              onPressed: () =>
                                  ref.invalidate(eligibleMembersProvider),
                            ),
                          ],
                        ),
                      ),
                      data: (all) {
                        final pool = all
                            .where((m) => !taken.contains(m.id))
                            .toList();
                        final filtered = pool
                            .where(
                              (m) => m.fullName.toLowerCase().contains(_query),
                            )
                            .toList();
                        if (pool.isEmpty) {
                          return SketchBox(
                            radius: 16,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No one else to add. You can invite people you '
                              'have shared an accepted activity with.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: SketchColors.inkFaint),
                            ),
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: filtered.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: Text('No matches')),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filtered.length,
                                      itemBuilder: (context, i) {
                                        final m = filtered[i];
                                        final checked = _selected.contains(
                                          m.id,
                                        );
                                        return EligibleMemberRow(
                                          member: m,
                                          checked: checked,
                                          disabled:
                                              !checked &&
                                              _selected.length >= capacity,
                                          onTap: () => _toggle(m.id),
                                        );
                                      },
                                    ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            SketchButton(
                              label: _submitting
                                  ? 'Sending...'
                                  : 'Send invitations (${_selected.length})',
                              icon: const Icon(Icons.send_rounded),
                              filled: true,
                              onPressed: (_submitting || _selected.isEmpty)
                                  ? null
                                  : () => _submit(pool),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
