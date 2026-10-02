import 'requester_preview.dart';

/// Covers both response shapes: the minimal one returned by the create
/// call (id, message, status, created_at only) and the full one
/// returned everywhere else (adds activityPost/activityTitle/requester/
/// declineReason) -- hence the nullable fields.
class JoinRequest {
  final String id;
  final String? activityPostId;
  final String? activityTitle;
  final RequesterPreview? requester;
  final String? message;
  final String status;
  final String? declineReason;
  final DateTime createdAt;

  const JoinRequest({
    required this.id,
    this.activityPostId,
    this.activityTitle,
    this.requester,
    this.message,
    required this.status,
    this.declineReason,
    required this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
    id: json['id'] as String,
    activityPostId: json['activity_post'] as String?,
    activityTitle: json['activity_title'] as String?,
    requester: json['requester'] != null
        ? RequesterPreview.fromJson(json['requester'] as Map<String, dynamic>)
        : null,
    message: json['message'] as String?,
    status: json['status'] as String,
    declineReason: json['decline_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
