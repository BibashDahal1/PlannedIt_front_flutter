import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../groups/data/social_groups_providers.dart';
import '../../groups/domain/social_group.dart';
import '../data/group_applications.dart';

/// Lets a social-group admin apply to an activity with their group.
/// The admin picks which group, then which members apply (any non-empty
/// subset). Pops with `true` once the request was sent.
class ApplyWithGroupSheet extends ConsumerStatefulWidget {
  final String activityId;
  const ApplyWithGroupSheet({super.key, required this.activityId});

  static Future<bool?> show(
    BuildContext context, {
    required String activityId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ApplyWithGroupSheet(activityId: activityId),
    );
  }

  @override
  ConsumerState<ApplyWithGroupSheet> createState() =>
      _ApplyWithGroupSheetState();
}

class _ApplyWithGroupSheetState extends ConsumerState<ApplyWithGroupSheet> {
  final _messageController = TextEditingController();
  final Set<String> _selected = {};
  String? _groupId;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Make sure a valid group is chosen; everyone is selected by default
  /// (the API treats "no member_ids" as "all members").
  void _ensureSelection(List<SocialGroup> adminGroups) {
    if (_groupId != null && adminGroups.any((g) => g.id == _groupId)) return;
    final first = adminGroups.first;
    _groupId = first.id;
    _selected
      ..clear()
      ..addAll(first.members.map((m) => m.id));
  }

  void _selectGroup(SocialGroup group) {
    setState(() {
      _groupId = group.id;
      _selected
        ..clear()
        ..addAll(group.members.map((m) => m.id));
      _error = null;
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      _error = null;
    });
  }

  Future<void> _submit(SocialGroup group) async {
    if (_submitting) return;
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one member to apply.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(groupApplicationsRepositoryProvider)
          .applyWithGroup(
            activityId: widget.activityId,
            groupId: group.id,
            memberIds: _selected.toList(),
            message: _messageController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractApiErrorMessage(e);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final groupsAsync = ref.watch(mySocialGroupsProvider);
    final spots = ref.watch(spotsRemainingProvider(widget.activityId)).value;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                      seed: 701,
                      radius: 14,
                      width: 48,
                      height: 48,
                      child: Center(child: SketchIcon('people', size: 30)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Apply with a group',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: groupsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => SketchBox(
                      radius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load your groups: '
                            '${extractApiErrorMessage(error)}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          SketchButton(
                            label: 'Try again',
                            icon: const Icon(Icons.refresh),
                            onPressed: () =>
                                ref.invalidate(mySocialGroupsProvider),
                          ),
                        ],
                      ),
                    ),
                    data: (groups) {
                      final adminGroups = groups
                          .where((g) => g.isAdmin)
                          .toList();
                      if (adminGroups.isEmpty) {
                        return SketchBox(
                          radius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Only a group admin can apply with a group. '
                            'Create a group from the Groups screen first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SketchColors.inkFaint),
                          ),
                        );
                      }
                      _ensureSelection(adminGroups);
                      final group = adminGroups.firstWhere(
                        (g) => g.id == _groupId,
                      );
                      return _buildForm(context, adminGroups, group, spots);
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

  Widget _buildForm(
    BuildContext context,
    List<SocialGroup> adminGroups,
    SocialGroup group,
    int? spots,
  ) {
    final theme = Theme.of(context);
    final allSelected = _selected.length == group.members.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              // ---------- Group chooser (only when admin of several) ----------
              if (adminGroups.length > 1) ...[
                Text(
                  'Group',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: adminGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final g = adminGroups[i];
                      final selected = g.id == group.id;
                      return SizedBox(
                        width: 170,
                        child: SketchBox(
                          seed: g.id.hashCode,
                          radius: 14,
                          fill: selected
                              ? SketchColors.ink.withValues(alpha: 0.08)
                              : null,
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _selectGroup(g),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${g.memberCount} members',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: SketchColors.inkFaint,
                                      ),
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
                const SizedBox(height: 14),
              ],

              // ---------- Who applies ----------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Who is applying?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(group.members.map((m) => m.id));
                      }
                      _error = null;
                    }),
                    child: Text(allSelected ? 'Clear all' : 'Select all'),
                  ),
                ],
              ),
              _CapacityNote(spots: spots, selected: _selected.length),
              const SizedBox(height: 8),
              for (final m in group.members)
                _ApplyMemberRow(
                  member: m,
                  checked: _selected.contains(m.id),
                  onTap: () => _toggle(m.id),
                ),

              // ---------- Message ----------
              const SizedBox(height: 8),
              Text(
                'Message (optional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SketchBox(
                seed: 702,
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "We'd like to join",
                    hintStyle: TextStyle(color: SketchColors.inkFaint),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 12),
        SketchButton(
          label: _submitting
              ? 'Sending...'
              : 'Send request (${_selected.length})',
          icon: const Icon(Icons.send_rounded),
          filled: true,
          onPressed: _submitting ? null : () => _submit(group),
        ),
      ],
    );
  }
}

/// Explains how the selection compares to the spots left. The host makes the
/// final choice, so too many or too few is allowed; this only informs.
class _CapacityNote extends StatelessWidget {
  final int? spots;
  final int selected;
  const _CapacityNote({required this.spots, required this.selected});

  @override
  Widget build(BuildContext context) {
    final String text;
    if (selected == 0) {
      text = 'Select at least one member to apply.';
    } else if (spots == null) {
      text = '$selected selected. The host chooses who joins.';
    } else if (spots == 0) {
      text = 'No spots are left right now.';
    } else if (selected > spots!) {
      text =
          '$selected selected but only $spots spot${spots == 1 ? '' : 's'} '
          'left. You can still apply; the host will pick up to $spots of you.';
    } else {
      text =
          '$spots spot${spots == 1 ? '' : 's'} left. The host can accept '
          '${selected == 1 ? 'your selected member' : 'all $selected of you'}'
          '${selected < spots! ? ', and there is room for more' : ''}.';
    }

    return SketchBox(
      seed: 703,
      radius: 12,
      fill: null,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: SketchColors.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SketchColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyMemberRow extends StatelessWidget {
  final SocialGroupMember member;
  final bool checked;
  final VoidCallback onTap;

  const _ApplyMemberRow({
    required this.member,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seed = member.id.hashCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SketchBox(
        seed: seed,
        radius: 14,
        fill: checked ? SketchColors.ink.withValues(alpha: 0.08) : null,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  UserAvatar(avatarUrl: member.avatar, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName
                          : 'Unknown member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (member.isAdmin) ...[
                    const SizedBox(width: 8),
                    Text(
                      'You',
                      style: TextStyle(
                        fontSize: 12,
                        color: SketchColors.inkFaint,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  SketchBox(
                    seed: seed + 1,
                    radius: 8,
                    width: 28,
                    height: 28,
                    fill: checked ? SketchColors.ink : null,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: checked
                          ? Icon(
                              Icons.check,
                              size: 18,
                              color: SketchColors.paper,
                            )
                          : const SizedBox.shrink(),
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
