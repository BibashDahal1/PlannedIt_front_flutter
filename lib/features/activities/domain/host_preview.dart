class HostPreview {
  final String id;
  final String fullName;
  final String trustTier;
  final String verificationStatus;
  final String?
  avatar; // not in the current API response shape -- see note below

  const HostPreview({
    required this.id,
    required this.fullName,
    required this.trustTier,
    required this.verificationStatus,
    this.avatar,
  });

  factory HostPreview.fromJson(Map<String, dynamic> json) => HostPreview(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    trustTier: json['trust_tier'] as String,
    verificationStatus: json['verification_status'] as String,
    avatar: json['avatar'] as String?,
  );
}
