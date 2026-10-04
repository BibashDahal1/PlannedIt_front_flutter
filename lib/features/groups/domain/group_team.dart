class GroupTeam {
  final String? id;
  final String name;
  final List<String> memberIds;

  const GroupTeam({
    this.id,
    required this.name,
    required this.memberIds,
  });

  factory GroupTeam.fromJson(Map<String, dynamic> json) => GroupTeam(
    id: json['id'] as String?,
    name: json['name'] as String,
    memberIds: (json['member_ids'] as List? ?? const [])
        .map((id) => id as String)
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'member_ids': memberIds,
  };
}
