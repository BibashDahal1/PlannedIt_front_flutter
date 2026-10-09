class PendingActivityRating {
  final String activityId;
  final String activityTitle;
  final DateTime scheduledEnd;
  final String groupId;
  final String myRole;
  final List<PendingRatee> ratees;

  const PendingActivityRating({
    required this.activityId,
    required this.activityTitle,
    required this.scheduledEnd,
    required this.groupId,
    required this.myRole,
    required this.ratees,
  });

  factory PendingActivityRating.fromJson(Map<String, dynamic> json) =>
      PendingActivityRating(
        activityId: json['activity_id'] as String,
        activityTitle: json['activity_title'] as String? ?? '',
        scheduledEnd: DateTime.parse(json['scheduled_end'] as String),
        groupId: json['group_id'] as String,
        myRole: json['my_role'] as String? ?? '',
        ratees: (json['ratees'] as List<dynamic>? ?? const [])
            .map(
              (ratee) => PendingRatee.fromJson(ratee as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
}

class PendingRatee {
  final String id;
  final String fullName;
  final String role;
  final String? avatar;

  const PendingRatee({
    required this.id,
    required this.fullName,
    required this.role,
    this.avatar,
  });

  factory PendingRatee.fromJson(Map<String, dynamic> json) => PendingRatee(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: json['role'] as String? ?? '',
    avatar: json['avatar'] as String?,
  );
}
