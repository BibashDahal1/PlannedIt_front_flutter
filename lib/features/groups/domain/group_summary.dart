class GroupSummary {
  final String id;
  final String activityTitle;
  final int memberCount;
  final List<String>? memberNames;

  const GroupSummary({
    required this.id,
    required this.activityTitle,
    required this.memberCount,
    this.memberNames = const [],
  });

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List? ?? const [];
    final memberNames = members
        .whereType<Map<String, dynamic>>()
        .map((member) => member['full_name'] as String? ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);

    return GroupSummary(
      id: json['id'] as String,
      activityTitle: json['activity_title'] as String? ?? 'Activity',
      memberCount: members.length,
      memberNames: memberNames,
    );
  }
}
