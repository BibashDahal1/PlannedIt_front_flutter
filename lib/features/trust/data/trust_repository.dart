import '../domain/public_profile.dart';
import '../domain/pending_activity_rating.dart';
import '../domain/rating.dart';
import 'trust_api.dart';

class TrustRepository {
  TrustRepository(this._api);
  final TrustApi _api;

  Future<void> completeActivity(String activityId) =>
      _api.completeActivity(activityId);

  Future<List<PendingActivityRating>> fetchPendingRatings() =>
      _api.fetchPendingRatings();

  Future<Rating> submitRating(
    String activityId, {
    required String rateeId,
    required int score,
    String? comment,
    List<String>? tags,
  }) => _api.submitRating(
    activityId,
    rateeId: rateeId,
    score: score,
    comment: comment,
    tags: tags,
  );

  Future<PublicProfile> fetchPublicProfile(String userId) =>
      _api.fetchPublicProfile(userId);

  Future<void> submitReport({
    required String reportedUserId,
    String? activityPostId,
    required String reason,
    String? details,
  }) => _api.submitReport(
    reportedUserId: reportedUserId,
    activityPostId: activityPostId,
    reason: reason,
    details: details,
  );

  Future<void> blockUser(String userId) => _api.blockUser(userId);
}
