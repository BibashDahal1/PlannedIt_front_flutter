/// Form-side input model for POST /activities. Kept separate from
/// ActivityPost so the create form's mutable draft state doesn't leak
/// into the read-only response model.
class CreateActivityInput {
  final int categoryId;
  final double latitude;
  final double longitude;
  final String? addressText;
  final String? venueName;
  final String title;
  final String? description;
  final int totalSpotsNeeded;
  final int? teamSize;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String
  visibility; // 'public' | 'nearby_only' | 'invite_only' -- confirm exact enum with backend
  final String
  minVerificationTier; // 'basic' | 'social_verified' | 'fully_verified'

  const CreateActivityInput({
    required this.categoryId,
    required this.latitude,
    required this.longitude,
    this.addressText,
    this.venueName,
    required this.title,
    this.description,
    required this.totalSpotsNeeded,
    this.teamSize,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.visibility = 'public',
    this.minVerificationTier = 'basic',
  });

  Map<String, dynamic> toJson() => {
    'category': categoryId,
    'location': {
      'latitude': latitude,
      'longitude': longitude,
      if (addressText != null) 'address_text': addressText,
      if (venueName != null) 'venue_name': venueName,
    },
    'title': title,
    if (description != null) 'description': description,
    'total_spots_needed': totalSpotsNeeded,
    if (teamSize != null) 'team_size': teamSize,
    'scheduled_start': scheduledStart.toUtc().toIso8601String(),
    'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
    'visibility': visibility,
    'min_verification_tier': minVerificationTier,
  };
}
