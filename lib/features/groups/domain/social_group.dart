/// A person the current user has shared an accepted activity group with,
/// and who can therefore be added to a social group.
class EligibleMember {
  final String id;
  final String fullName;
  final String? avatar;
  final String trustTier;

  const EligibleMember({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.trustTier,
  });

  factory EligibleMember.fromJson(Map<String, dynamic> json) => EligibleMember(
    id: json['id'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    avatar: json['avatar'] as String?,
    trustTier: (json['trust_tier'] as String?) ?? '',
  );
}

class SocialGroupMember {
  final String id;
  final String fullName;
  final String? avatar;
  final String role; // 'admin' | 'member'

  const SocialGroupMember({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory SocialGroupMember.fromJson(Map<String, dynamic> json) =>
      SocialGroupMember(
        id: json['id'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        avatar: json['avatar'] as String?,
        role: (json['role'] as String?) ?? 'member',
      );
}

class SocialGroup {
  final String id;
  final String name;
  final List<SocialGroupMember> members;
  final int memberCount;
  final bool isAdmin;

  const SocialGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.memberCount,
    required this.isAdmin,
  });

  factory SocialGroup.fromJson(Map<String, dynamic> json) {
    final members = ((json['members'] as List?) ?? const [])
        .map((m) => SocialGroupMember.fromJson(m as Map<String, dynamic>))
        .toList();
    return SocialGroup(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      members: members,
      memberCount: (json['member_count'] as int?) ?? members.length,
      isAdmin: (json['is_admin'] as bool?) ?? false,
    );
  }
}
