class PublicProfile {
  final String id;
  final String fullName;
  final String? avatar;
  final String verificationStatus;
  final String trustTier;
  final double? averageRating;
  final int ratingsCount;
  final int activitiesHosted;
  final DateTime dateJoined;

  const PublicProfile({
    required this.id,
    required this.fullName,
    this.avatar,
    required this.verificationStatus,
    required this.trustTier,
    this.averageRating,
    required this.ratingsCount,
    required this.activitiesHosted,
    required this.dateJoined,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    avatar: json['avatar'] as String?,
    verificationStatus: json['verification_status'] as String,
    trustTier: json['trust_tier'] as String,
    averageRating: (json['average_rating'] as num?)?.toDouble(),
    ratingsCount: json['ratings_count'] as int,
    activitiesHosted: json['activities_hosted'] as int,
    dateJoined: DateTime.parse(json['date_joined'] as String),
  );
}
