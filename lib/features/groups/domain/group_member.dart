class GroupMember {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String trustTier;
  final String role;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.trustTier,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    phoneNumber: json['phone_number'] as String,
    trustTier: json['trust_tier'] as String,
    role: json['role'] as String,
    joinedAt: DateTime.parse(json['joined_at'] as String),
  );
}
