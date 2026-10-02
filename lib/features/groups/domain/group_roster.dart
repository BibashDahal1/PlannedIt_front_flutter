import 'group_member.dart';

class GroupRoster {
  final String id;
  final String activityId;
  final String activityTitle;
  final List<GroupMember> members;
  final DateTime createdAt;

  const GroupRoster({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.members,
    required this.createdAt,
  });

  factory GroupRoster.fromJson(Map<String, dynamic> json) => GroupRoster(
    id: json['id'] as String,
    activityId: json['activity_id'] as String,
    activityTitle: json['activity_title'] as String,
    members: (json['members'] as List)
        .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
