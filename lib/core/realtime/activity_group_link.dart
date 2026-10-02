class ActivityGroupLink {
  final String groupId;
  final String activityTitle;
  const ActivityGroupLink({required this.groupId, required this.activityTitle});

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'activity_title': activityTitle,
  };

  factory ActivityGroupLink.fromJson(Map<String, dynamic> json) =>
      ActivityGroupLink(
        groupId: json['group_id'] as String,
        activityTitle: json['activity_title'] as String? ?? 'Activity',
      );
}
