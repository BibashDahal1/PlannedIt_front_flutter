/// A person the current user has shared an accepted activity group with,
/// and who can therefore be invited to a social group.
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

/// Someone the admin invited who has not answered yet (admin-only data).
class SocialGroupPendingInvite {
  final String id; // invitation id
  final String userId;
  final String fullName;

  const SocialGroupPendingInvite({
    required this.id,
    required this.userId,
    required this.fullName,
  });

  factory SocialGroupPendingInvite.fromJson(Map<String, dynamic> json) =>
      SocialGroupPendingInvite(
        id: json['id'] as String,
        userId: (json['user_id'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
      );
}

class SocialGroup {
  final String id;
  final String name;
  final List<SocialGroupMember> members;
  final int memberCount;
  final bool isAdmin;
  final List<SocialGroupPendingInvite> pendingInvitations;

  const SocialGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.memberCount,
    required this.isAdmin,
    this.pendingInvitations = const [],
  });

  /// The group chat opens only once someone besides the admin has accepted.
  bool get canChat => memberCount > 1;

  factory SocialGroup.fromJson(Map<String, dynamic> json) {
    final members = ((json['members'] as List?) ?? const [])
        .map((m) => SocialGroupMember.fromJson(m as Map<String, dynamic>))
        .toList();
    final pending = ((json['pending_invitations'] as List?) ?? const [])
        .map(
          (m) => SocialGroupPendingInvite.fromJson(m as Map<String, dynamic>),
        )
        .toList();
    return SocialGroup(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      members: members,
      memberCount: (json['member_count'] as int?) ?? members.length,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      pendingInvitations: pending,
    );
  }
}

/// An invitation to join someone else's social group.
class SocialGroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final int groupMemberCount;
  final String invitedById;
  final String invitedByName;
  final String? invitedByAvatar;
  final DateTime? createdAt;

  const SocialGroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupMemberCount,
    required this.invitedById,
    required this.invitedByName,
    this.invitedByAvatar,
    this.createdAt,
  });

  factory SocialGroupInvitation.fromJson(Map<String, dynamic> json) {
    final group = (json['group'] as Map?)?.cast<String, dynamic>() ?? const {};
    final by =
        (json['invited_by'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SocialGroupInvitation(
      id: json['id'] as String,
      groupId: (group['id'] as String?) ?? '',
      groupName: (group['name'] as String?) ?? 'Group',
      groupMemberCount: (group['member_count'] as num?)?.toInt() ?? 0,
      invitedById: (by['id'] as String?) ?? '',
      invitedByName: (by['full_name'] as String?) ?? '',
      invitedByAvatar: by['avatar'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}
