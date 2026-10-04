import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../activities/data/activities_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/groups_providers.dart';
import '../../groups/domain/group_member.dart';
import '../../groups/domain/group_roster.dart';
import '../../groups/domain/group_team.dart';
import 'dashboard_widgets.dart';

class TeamManagementTab extends ConsumerStatefulWidget {
  final String groupId;

  const TeamManagementTab({super.key, required this.groupId});

  @override
  ConsumerState<TeamManagementTab> createState() => _TeamManagementTabState();
}

class _TeamManagementTabState extends ConsumerState<TeamManagementTab> {
  String? _draftGroupId;
  List<_TeamDraft> _draftTeams = [];
  bool _isSaving = false;
  bool _initializationScheduled = false;

  List<_TeamDraft> _initialTeams(GroupRoster roster, int? teamSize) {
    if (roster.teams.isNotEmpty) {
      return roster.teams
          .map((team) => _TeamDraft(team.name, team.memberIds.toSet()))
          .toList();
    }
    final teamCount = teamSize != null && teamSize > 0
        ? math.max(1, (roster.members.length / teamSize).ceil())
        : math.min(3, math.max(1, roster.members.length));
    return List.generate(
      teamCount,
      (index) => _TeamDraft(_teamName(index), <String>{}),
    );
  }

  String _teamName(int index) {
    var value = index;
    var name = '';
    do {
      name = String.fromCharCode(65 + value % 26) + name;
      value = value ~/ 26 - 1;
    } while (value >= 0);
    return 'Team $name';
  }

  void _initializeDraft(GroupRoster roster, int? teamSize) {
    if (_draftGroupId == roster.id || _initializationScheduled) return;
    _initializationScheduled = true;
    final teams = _initialTeams(roster, teamSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializationScheduled = false;
      if (!mounted) return;
      setState(() {
        _draftGroupId = roster.id;
        _draftTeams = teams;
      });
    });
  }

  int? _capacity(int? teamSize) =>
      teamSize != null && teamSize > 0 ? teamSize : null;

  bool _assignMember({
    required String teamName,
    required GroupMember member,
    required int? capacity,
  }) {
    final teamIndex = _draftTeams.indexWhere((team) => team.name == teamName);
    if (teamIndex < 0) return false;
    final target = _draftTeams[teamIndex];
    if (target.memberIds.contains(member.id)) return false;
    final matchingSources = _draftTeams.where(
      (team) => team.memberIds.contains(member.id),
    );
    final source = matchingSources.isEmpty ? null : matchingSources.first;
    final isFull = capacity != null && target.memberIds.length >= capacity;
    if (isFull && source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$teamName is full (maximum $capacity).')),
      );
      return false;
    }
    setState(() {
      if (isFull && source != null && source != target) {
        final displacedMemberId = target.memberIds.first;
        source.memberIds.remove(member.id);
        target.memberIds.remove(displacedMemberId);
        target.memberIds.add(member.id);
        source.memberIds.add(displacedMemberId);
      } else {
        for (final team in _draftTeams) {
          team.memberIds.remove(member.id);
        }
        target.memberIds.add(member.id);
      }
    });
    return true;
  }

  void _unassignMember(GroupMember member) {
    setState(() {
      for (final team in _draftTeams) {
        team.memberIds.remove(member.id);
      }
    });
  }

  Future<void> _chooseTeamForMember({
    required GroupMember member,
    required List<_TeamDraft> teams,
    required int? capacity,
  }) async {
    final selectedTeam = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Move ${member.fullName} to a team',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...teams.map((team) {
              final alreadyAssigned = team.memberIds.contains(member.id);
              final isFull =
                  capacity != null && team.memberIds.length >= capacity;
              final assignedElsewhere = teams.any(
                (candidate) =>
                    candidate.name != team.name &&
                    candidate.memberIds.contains(member.id),
              );
              final disabled = isFull && !alreadyAssigned && !assignedElsewhere;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Opacity(
                  opacity: disabled ? 0.45 : 1,
                  child: SketchBox(
                    seed: team.name.hashCode,
                    radius: 14,
                    padding: const EdgeInsets.all(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: disabled
                          ? null
                          : () => Navigator.of(context).pop(team.name),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  capacity == null
                                      ? '${team.memberIds.length} members'
                                      : '${team.memberIds.length}/$capacity members',
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            alreadyAssigned
                                ? Icons.check_circle
                                : disabled
                                ? Icons.block
                                : Icons.arrow_forward,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
    if (selectedTeam != null && mounted) {
      _assignMember(teamName: selectedTeam, member: member, capacity: capacity);
    }
  }

  Future<void> _saveTeams(
    GroupRoster roster, {
    required bool isHost,
    required int? capacity,
  }) async {
    if (!isHost) {
      _showMessage('Only the group host can update teams.');
      return;
    }
    final memberIds = roster.members.map((member) => member.id).toSet();
    final assignedIds = _draftTeams
        .expand((team) => team.memberIds)
        .toList(growable: false);
    final uniqueNames = _draftTeams
        .map((team) => team.name.trim().toLowerCase())
        .toSet();
    if (uniqueNames.length != _draftTeams.length ||
        _draftTeams.any((team) => team.name.trim().isEmpty)) {
      _showMessage('Team names must be unique and cannot be blank.');
      return;
    }
    if (capacity != null &&
        _draftTeams.any((team) => team.memberIds.length > capacity)) {
      _showMessage('A team cannot have more than $capacity members.');
      return;
    }
    if (assignedIds.length != memberIds.length ||
        assignedIds.toSet().length != assignedIds.length ||
        !assignedIds.toSet().containsAll(memberIds)) {
      _showMessage('Assign every group member exactly once before saving.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updated = await ref
          .read(groupsApiProvider)
          .updateTeams(
            roster.id,
            _draftTeams
                .map(
                  (team) => GroupTeam(
                    name: team.name.trim(),
                    memberIds: team.memberIds.toList(growable: false),
                  ),
                )
                .toList(growable: false),
          );
      ref.invalidate(groupRosterProvider(roster.id));
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      setState(() {
        _draftGroupId = updated.id;
        _draftTeams = updated.teams
            .map((team) => _TeamDraft(team.name, team.memberIds.toSet()))
            .toList();
      });
      _showMessage('Teams saved and confirmed.');
    } catch (error) {
      if (mounted) _showMessage(extractApiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addTeam() {
    final used = _draftTeams.map((team) => team.name).toSet();
    var index = _draftTeams.length;
    while (used.contains(_teamName(index))) {
      index++;
    }
    setState(() => _draftTeams.add(_TeamDraft(_teamName(index), <String>{})));
  }

  void _removeTeam(_TeamDraft team) {
    if (_draftTeams.length <= 1) {
      _showMessage('A group must have at least one team.');
      return;
    }
    setState(() => _draftTeams.remove(team));
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(groupRosterProvider(widget.groupId));
    return rosterAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DashboardError(
        message: 'Could not load group: ${extractApiErrorMessage(error)}',
        onRetry: () => ref.invalidate(groupRosterProvider(widget.groupId)),
      ),
      data: (roster) {
        final activityAsync = ref.watch(
          activityDetailProvider(roster.activityId),
        );
        return activityAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DashboardError(
            message:
                'Could not load activity team settings: ${extractApiErrorMessage(error)}',
            onRetry: () =>
                ref.invalidate(activityDetailProvider(roster.activityId)),
          ),
          data: (activity) {
            _initializeDraft(roster, activity.teamSize);
            final teams = _draftGroupId == roster.id
                ? _draftTeams
                : _initialTeams(roster, activity.teamSize);
            final currentUserId = ref
                .watch(authControllerProvider)
                .value
                ?.user
                ?.id;
            final isHost = roster.members.any(
              (member) =>
                  member.id == currentUserId &&
                  member.role.toLowerCase() == 'host',
            );
            final capacity = _capacity(activity.teamSize);
            final assigned = teams.expand((team) => team.memberIds).toSet();
            final availableMembers = roster.members
                .where((member) => !assigned.contains(member.id))
                .toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Arrange your teams',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                capacity == null
                                    ? '${roster.members.length} group members'
                                    : '${roster.members.length} members · up to $capacity per team',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isHost) ...[
                          IconButton(
                            tooltip: 'Add team',
                            onPressed: _addTeam,
                            icon: const SketchIcon('plus', size: 26),
                          ),
                          FilledButton.icon(
                            onPressed:
                                _isSaving ||
                                    _draftGroupId != roster.id ||
                                    availableMembers.isNotEmpty ||
                                    (capacity != null &&
                                        teams.any(
                                          (team) =>
                                              team.memberIds.length > capacity,
                                        ))
                                ? null
                                : () => _saveTeams(
                                    roster,
                                    isHost: isHost,
                                    capacity: capacity,
                                  ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Save teams'),
                          ),
                        ],
                      ],
                    ),
                    if (!isHost)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Only the group host can update teams.'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 950
                              ? 3
                              : constraints.maxWidth >= 620
                              ? 2
                              : 1;
                          return GridView.builder(
                            itemCount: teams.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: columns == 1 ? 1.45 : 1.15,
                                ),
                            itemBuilder: (context, index) {
                              final team = teams[index];
                              final teamMembers = roster.members
                                  .where(
                                    (member) =>
                                        team.memberIds.contains(member.id),
                                  )
                                  .toList(growable: false);
                              final isFull =
                                  capacity != null &&
                                  team.memberIds.length >= capacity;
                              return DragTarget<GroupMember>(
                                hitTestBehavior: HitTestBehavior.opaque,
                                onWillAcceptWithDetails: (details) {
                                  final assignedElsewhere = teams.any(
                                    (candidate) =>
                                        candidate.name != team.name &&
                                        candidate.memberIds.contains(
                                          details.data.id,
                                        ),
                                  );
                                  return isHost &&
                                      (!isFull || assignedElsewhere);
                                },
                                onAcceptWithDetails: (details) => _assignMember(
                                  teamName: team.name,
                                  member: details.data,
                                  capacity: capacity,
                                ),
                                builder: (context, candidates, _) {
                                  return SketchBox(
                                    seed: team.name.hashCode,
                                    radius: 18,
                                    strokeColor: candidates.isNotEmpty
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    strokeWidth: candidates.isNotEmpty
                                        ? 2
                                        : 1.6,
                                    fill: candidates.isNotEmpty
                                        ? SketchColors.paperFleck.withValues(
                                            alpha: 0.45,
                                          )
                                        : SketchColors.paper,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                team.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              capacity == null
                                                  ? '${team.memberIds.length}'
                                                  : '${team.memberIds.length}/$capacity',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium,
                                            ),
                                            if (isHost && teams.length > 1)
                                              IconButton(
                                                tooltip: 'Remove ${team.name}',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _removeTeam(team),
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: teamMembers.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    isHost
                                                        ? 'Drop members here'
                                                        : 'No members assigned',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                )
                                              : SingleChildScrollView(
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: teamMembers
                                                        .map(
                                                          (
                                                            member,
                                                          ) => _MemberDragTile(
                                                            member: member,
                                                            enabled: isHost,
                                                            onRemove: isHost
                                                                ? () =>
                                                                      _unassignMember(
                                                                        member,
                                                                      )
                                                                : null,
                                                            onTap: isHost
                                                                ? () => _chooseTeamForMember(
                                                                    member:
                                                                        member,
                                                                    teams:
                                                                        teams,
                                                                    capacity:
                                                                        capacity,
                                                                  )
                                                                : null,
                                                          ),
                                                        )
                                                        .toList(
                                                          growable: false,
                                                        ),
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Activity members (${roster.members.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (roster.teamsConfirmed)
                          const Chip(
                            avatar: Icon(Icons.verified_outlined, size: 16),
                            label: Text('Confirmed'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 82,
                      child: roster.members.isEmpty
                          ? const Center(
                              child: Text('No members in this group yet.'),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: roster.members.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final member = roster.members[index];
                                final matchingTeams = teams.where(
                                  (team) => team.memberIds.contains(member.id),
                                );
                                final assignedTeam = matchingTeams.isEmpty
                                    ? null
                                    : matchingTeams.first.name;
                                return _MemberDragTile(
                                  member: member,
                                  enabled: isHost,
                                  teamLabel: assignedTeam,
                                  onTap: isHost
                                      ? () => _chooseTeamForMember(
                                          member: member,
                                          teams: teams,
                                          capacity: capacity,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamDraft {
  final String name;
  final Set<String> memberIds;

  _TeamDraft(this.name, this.memberIds);
}

class _MemberDragTile extends StatelessWidget {
  final GroupMember member;
  final bool enabled;
  final String? teamLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _MemberDragTile({
    required this.member,
    required this.enabled,
    this.teamLabel,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = member.fullName.isEmpty ? 'Member' : member.fullName;
    final message = teamLabel == null
        ? '$displayName${enabled ? ' · press and hold to drag or tap to assign' : ''}'
        : '$displayName · $teamLabel';
    final memberContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(avatarUrl: member.avatar, radius: 22),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (member.role.toLowerCase() == 'host') ...[
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 15, color: Colors.amber),
        ],
      ],
    );

    return Tooltip(
      message: message,
      child: SketchBox(
        seed: member.id.hashCode,
        radius: 14,
        padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6, right: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enabled)
              LongPressDraggable<GroupMember>(
                data: member,
                delay: const Duration(milliseconds: 250),
                dragAnchorStrategy: pointerDragAnchorStrategy,
                hapticFeedbackOnStart: true,
                feedback: Material(
                  color: Colors.transparent,
                  child: SketchBox(
                    seed: member.id.hashCode,
                    radius: 14,
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        memberContent,
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_indicator),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: memberContent),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: memberContent,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              memberContent,
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Remove ${member.fullName} from $teamLabel',
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 34,
                ),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
