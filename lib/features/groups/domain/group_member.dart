class GroupMember {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String trustTier;
  final String role;
  final String? avatar;
  final String? teamId;
  final String? teamName;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.trustTier,
    required this.role,
    this.avatar,
    this.teamId,
    this.teamName,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>?;
    return GroupMember(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      trustTier: json['trust_tier'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatar: json['avatar'] as String?,
      teamId: team?['id'] as String?,
      teamName: team?['name'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
