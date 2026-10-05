import 'social_profile.dart';

class AppUser {
  final String id;
  final String phoneNumber;
  final String? email;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? avatar;
  final String verificationStatus;
  final String trustTier;
  final bool isPhoneVerified;
  final DateTime dateJoined;
  final List<SocialProfile> socialProfiles;

  const AppUser({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.fullName,
    this.dateOfBirth,
    this.avatar,
    required this.verificationStatus,
    required this.trustTier,
    required this.isPhoneVerified,
    required this.dateJoined,
    this.socialProfiles = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    phoneNumber: json['phone_number'] as String,
    email: json['email'] as String?,
    fullName: json['full_name'] as String? ?? '',
    dateOfBirth: json['date_of_birth'] != null
        ? DateTime.parse(json['date_of_birth'] as String)
        : null,
    avatar: json['avatar'] as String?,
    verificationStatus: json['verification_status'] as String,
    trustTier: json['trust_tier'] as String,
    isPhoneVerified: json['is_phone_verified'] as bool,
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
