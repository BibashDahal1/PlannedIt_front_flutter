class NotificationEvent {
  final String event;
  final String? joinRequestId;
  final String? activityId;
  final String? activityTitle;
  final String? requesterId;
  final String? requesterName;
  final String? groupId;
  final String? reason;
  final String? message;

  const NotificationEvent({
    required this.event,
    this.joinRequestId,
    this.activityId,
    this.activityTitle,
    this.requesterId,
    this.requesterName,
    this.groupId,
    this.reason,
    this.message,
  });

  factory NotificationEvent.fromJson(Map<String, dynamic> json) =>
      NotificationEvent(
        event: json['event'] as String,
        joinRequestId: json['join_request_id'] as String?,
        activityId: json['activity_id'] as String?,
        activityTitle: json['activity_title'] as String?,
        requesterId: json['requester_id'] as String?,
        requesterName: json['requester_name'] as String?,
        groupId: json['group_id'] as String?,
        reason: json['reason'] as String?,
        message: json['message'] as String?,
      );

  String get displayMessage {
    switch (event) {
      case 'new_join_request':
        return 'New request for "$activityTitle"';
      case 'request_accepted':
        return 'Your request for "$activityTitle" was accepted!';
      case 'request_declined':
        return 'Your request for "$activityTitle" was declined.';
      case 'roster_updated':
        return 'An activity you\'re in just got a roster update.';
      case 'activity_cancelled':
        return '"$activityTitle" was cancelled by the host.';
      case 'activity_deleted':
        return message ?? '"$activityTitle" has been deleted.';
      default:
        return event;
    }
  }
}
