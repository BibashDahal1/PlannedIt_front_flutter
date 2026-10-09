import '../../auth/domain/social_profile.dart';

class RequesterPreview {
  final String id;
  final String fullName;
  final String? avatar;
  final String verificationStatus;
  final String trustTier;
  final DateTime dateJoined;
  final List<SocialProfile> socialProfiles;

  const RequesterPreview({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.verificationStatus,
    required this.trustTier,
    required this.dateJoined,
    this.socialProfiles = const [],
  });

  factory RequesterPreview.fromJson(Map<String, dynamic> json) =>
      RequesterPreview(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        avatar: json['avatar'] as String?,
        verificationStatus: json['verification_status'] as String,
        trustTier: json['trust_tier'] as String,
        dateJoined: DateTime.parse(json['date_joined'] as String),
        socialProfiles: (json['social_profiles'] as List? ?? const [])
            .map(
              (profile) => SocialProfile.fromJson(
                Map<String, dynamic>.from(profile as Map),
              ),
            )
            .toList(growable: false),
      );
}
