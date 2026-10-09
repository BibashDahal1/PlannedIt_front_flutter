import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/sketch_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../groups/data/groups_providers.dart';

/// Members of an activity group, shown from the chat screen's menu button.
/// Replaces the old plain ListTile sheet with sketch-style rows.
class GroupMembersSheet extends ConsumerWidget {
  final String groupId;
  const GroupMembersSheet({super.key, required this.groupId});

  static String _label(String value) => value
      .trim()
      .split(RegExp(r'[_\s]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when dark mode is toggled so SketchColors are re-read.
    ref.watch(themeModeProvider);
    final rosterAsync = ref.watch(groupRosterProvider(groupId));
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SketchColors.inkFaint.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SketchBox(
                    seed: 601,
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
                          'Group members',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        rosterAsync.maybeWhen(
                          data: (roster) => Text(
                            '${roster.members.length} '
                            '${roster.members.length == 1 ? 'person' : 'people'}',
                            style: TextStyle(color: SketchColors.inkFaint),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: rosterAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => SketchBox(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not load group members.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        SketchButton(
                          label: 'Retry',
                          icon: const Icon(Icons.refresh),
                          onPressed: () =>
                              ref.invalidate(groupRosterProvider(groupId)),
                        ),
                      ],
                    ),
                  ),
                  data: (roster) {
                    if (roster.members.isEmpty) {
                      return SketchBox(
                        radius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No members found.',
                            style: TextStyle(color: SketchColors.inkFaint),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: roster.members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = roster.members[index];
                        final role = _label(member.role);
                        final name = member.fullName.isNotEmpty
                            ? member.fullName
                            : 'Unknown member';
                        final seed = '${member.fullName}$index'.hashCode;

                        return SketchBox(
                          seed: seed,
                          radius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(avatarUrl: member.avatar, radius: 21),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (role.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                SketchBox(
                                  seed: seed + 1,
                                  radius: 10,
                                  fill: null,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
