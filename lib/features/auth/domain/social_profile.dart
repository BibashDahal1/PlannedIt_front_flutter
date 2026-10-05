class SocialProfile {
  final String platform;
  final String? username;
  final String? profileUrl;

  const SocialProfile({
    required this.platform,
    this.username,
    this.profileUrl,
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) => SocialProfile(
    platform: json['platform'] as String,
    username: json['username'] as String?,
    profileUrl: json['profile_url'] as String?,
  );
}
