import 'group_member.dart';
import 'group_team.dart';

class GroupRoster {
  final String id;
  final String activityId;
  final String activityTitle;
  final List<GroupMember> members;
  final List<GroupTeam> teams;
  final bool teamsConfirmed;
  final DateTime createdAt;

  const GroupRoster({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.members,
    this.teams = const [],
    this.teamsConfirmed = false,
    required this.createdAt,
  });

  factory GroupRoster.fromJson(Map<String, dynamic> json) => GroupRoster(
    id: json['id'] as String,
    activityId: json['activity_id'] as String,
    activityTitle: json['activity_title'] as String? ?? 'Activity',
    members: (json['members'] as List? ?? const [])
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    teams: (json['teams'] as List? ?? const [])
        .map((e) => GroupTeam.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    teamsConfirmed: json['teams_confirmed'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
