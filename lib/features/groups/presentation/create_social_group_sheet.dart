import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/social_groups_providers.dart';
import '../domain/social_group.dart';

/// Bottom-sheet form: name the group, tick people from the eligible list,
/// then create it. Pops with `true` when the group was created.
class CreateSocialGroupSheet extends ConsumerStatefulWidget {
  const CreateSocialGroupSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateSocialGroupSheet(),
    );
  }

  @override
  ConsumerState<CreateSocialGroupSheet> createState() =>
      _CreateSocialGroupSheetState();
}

class _CreateSocialGroupSheetState
    extends ConsumerState<CreateSocialGroupSheet> {
  // Group max is 10 including the admin, so 9 invitees at most.
  static const _maxInvitees = 9;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < _maxInvitees) {
        _selected.add(id);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(socialGroupsRepositoryProvider)
          .create(
            name: _nameController.text.trim(),
            memberIds: _selected.toList(),
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
    // Rebuild when dark mode is toggled so SketchColors are re-read.
    ref.watch(themeModeProvider);
    final membersAsync = ref.watch(eligibleMembersProvider);
    final theme = Theme.of(context);

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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Header ----------
                  Row(
                    children: [
                      const SketchBox(
                        seed: 501,
                        radius: 14,
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SketchIcon('dashboard_groups', size: 32),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Create a group',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Group name ----------
                  _FieldLabel('Group name'),
                  const SizedBox(height: 6),
                  SketchBox(
                    seed: 502,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'e.g. Weekend hikers',
                        hintStyle: TextStyle(color: SketchColors.inkFaint),
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return 'Enter a group name';
                        if (v.length > 80) return 'Max 80 characters';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---------- Members header ----------
                  Row(
                    children: [
                      Expanded(child: _FieldLabel('Add members')),
                      SketchBox(
                        seed: 503,
                        radius: 10,
                        fill: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          '${_selected.length} / $_maxInvitees',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SketchBox(
                    seed: 504,
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
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Text(
                      'People you have joined activities with. They get an invitation and join once they accept.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SketchColors.inkFaint,
                      ),
                    ),
                  ),

                  // ---------- Member list ----------
                  Flexible(
                    child: membersAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SketchBox(
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
                      ),
                      data: (members) {
                        if (members.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SketchBox(
                              radius: 16,
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No one to add yet. You can add people you have '
                                'shared an accepted activity with. You can still '
                                'create the group on your own.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: SketchColors.inkFaint),
                              ),
                            ),
                          );
                        }
                        final filtered = members
                            .where(
                              (m) => m.fullName.toLowerCase().contains(_query),
                            )
                            .toList();
                        if (filtered.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('No matches')),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final m = filtered[i];
                            final checked = _selected.contains(m.id);
                            final atLimit =
                                _selected.length >= _maxInvitees && !checked;
                            return _MemberRow(
                              member: m,
                              checked: checked,
                              disabled: atLimit,
                              onTap: () => _toggle(m.id),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SketchButton(
                    label: _submitting
                        ? 'Creating...'
                        : 'Create & send invites',
                    icon: const Icon(Icons.group_add),
                    filled: true,
                    onPressed: _submit,
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// One selectable person: sketch card, avatar, name, trust tier pill and a
/// sketch checkbox. Selected rows get a tinted fill.
class _MemberRow extends StatelessWidget {
  final EligibleMember member;
  final bool checked;
  final bool disabled;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.checked,
    required this.disabled,
    required this.onTap,
  });

  String get _tier {
    final t = member.trustTier;
    if (t.isEmpty) return '';
    return t
        .split(RegExp(r'[_\s]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final seed = member.id.hashCode;
    final tier = _tier;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Padding(
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
              onTap: disabled ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    UserAvatar(avatarUrl: member.avatar, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName.isNotEmpty
                                ? member.fullName
                                : 'Unknown member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (tier.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_outline,
                                  size: 14,
                                  color: SketchColors.inkFaint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tier,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SketchColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SketchCheck(seed: seed + 1, checked: checked),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchCheck extends StatelessWidget {
  final int seed;
  final bool checked;
  const _SketchCheck({required this.seed, required this.checked});

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: seed,
      radius: 8,
      width: 28,
      height: 28,
      fill: checked ? SketchColors.ink : null,
      padding: EdgeInsets.zero,
      child: Center(
        child: checked
            ? Icon(Icons.check, size: 18, color: SketchColors.paper)
            : const SizedBox.shrink(),
      ),
    );
  }
}
