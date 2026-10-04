import '../../../shared/models/category.dart';
import '../../../shared/models/activity_location.dart';
import 'host_preview.dart';

/// One model covers browse, nearby, detail and mine responses. Fields
/// that only some responses include (description, visibility, tier,
/// createdAt, distanceKm) are nullable.
class ActivityPost {
  final String id;
  final String title;
  final String? description;
  final Category category;
  final HostPreview host;
  final ActivityLocation location;
  final int totalSpotsNeeded;
  final int? teamSize;
  final bool costSharingEnabled;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String? visibility;
  final String? minVerificationTier;
  final String status;
  final DateTime? createdAt;
  final double? distanceKm; // only present on /activities/nearby

  const ActivityPost({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.host,
    required this.location,
    required this.totalSpotsNeeded,
    this.teamSize,
    this.costSharingEnabled = false,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.visibility,
    this.minVerificationTier,
    required this.status,
    this.createdAt,
    this.distanceKm,
  });

  factory ActivityPost.fromJson(
    Map<String, dynamic> json, {
    bool exactLocation = false,
  }) => ActivityPost(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
    host: HostPreview.fromJson(json['host'] as Map<String, dynamic>),
    location: ActivityLocation.fromJson(
      json['location'] as Map<String, dynamic>,
      // Either the caller knows it's exact (/mine), or the backend says so.
      exact: exactLocation || json['location_is_exact'] == true,
    ),
    totalSpotsNeeded: json['total_spots_needed'] as int,
    teamSize: json['team_size'] as int?,
    costSharingEnabled: json['cost_sharing_enabled'] as bool? ?? false,
    scheduledStart: DateTime.parse(json['scheduled_start'] as String).toLocal(),
    scheduledEnd: DateTime.parse(json['scheduled_end'] as String).toLocal(),
    visibility: json['visibility'] as String?,
    minVerificationTier: json['min_verification_tier'] as String?,
    status: json['status'] as String,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
  );
}
