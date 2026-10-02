class RequesterPreview {
  final String id;
  final String fullName;
  final String verificationStatus;
  final String trustTier;
  final DateTime dateJoined;

  const RequesterPreview({
    required this.id,
    required this.fullName,
    required this.verificationStatus,
    required this.trustTier,
    required this.dateJoined,
  });

  factory RequesterPreview.fromJson(Map<String, dynamic> json) =>
      RequesterPreview(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        verificationStatus: json['verification_status'] as String,
        trustTier: json['trust_tier'] as String,
        dateJoined: DateTime.parse(json['date_joined'] as String),
      );
}
