class ActivityLocation {
  final double latitude;
  final double longitude;
  final String? addressText;
  final String? venueName;

  /// True only when we know these are the real coordinates (the host's
  /// own /activities/mine data, or a response the backend marks with
  /// `location_is_exact`). Everything else is the ~1 km rounded version.
  final bool isExact;

  const ActivityLocation({
    required this.latitude,
    required this.longitude,
    this.addressText,
    this.venueName,
    this.isExact = false,
  });

  factory ActivityLocation.fromJson(
    Map<String, dynamic> json, {
    bool exact = false,
  }) => ActivityLocation(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    addressText: json['address_text'] as String?,
    venueName: json['venue_name'] as String?,
    isExact: exact,
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (addressText != null) 'address_text': addressText,
    if (venueName != null) 'venue_name': venueName,
  };
}
