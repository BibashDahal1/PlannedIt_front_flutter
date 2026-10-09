import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/public_profile.dart';
import '../domain/pending_activity_rating.dart';
import '../domain/rating.dart';

class TrustApi {
  TrustApi(this._dio);
  final Dio _dio;

  Future<void> completeActivity(String activityId) async {
    await _dio.post(ApiEndpoints.activityComplete(activityId));
  }

  Future<List<PendingActivityRating>> fetchPendingRatings() async {
    final response = await _dio.get(ApiEndpoints.pendingRatings);
    return (response.data as List<dynamic>)
        .map(
          (activity) => PendingActivityRating.fromJson(
            activity as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<Rating> submitRating(
    String activityId, {
    required String rateeId,
    required int score,
    String? comment,
    List<String>? tags,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.activityRatings(activityId),
      data: {
        'ratee': rateeId,
        'score': score,
        'comment': comment ?? '',
        'tags': tags ?? const <String>[],
      },
    );
    return Rating.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PublicProfile> fetchPublicProfile(String userId) async {
    final response = await _dio.get(ApiEndpoints.publicProfile(userId));
    return PublicProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitReport({
    required String reportedUserId,
    String? activityPostId,
    required String reason,
    String? details,
  }) async {
    await _dio.post(
      ApiEndpoints.reports,
      data: {
        'reported_user': reportedUserId,
        if (activityPostId != null) 'activity_post': activityPostId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }

  Future<void> blockUser(String userId) async {
    await _dio.post(ApiEndpoints.blocks, data: {'blocked': userId});
  }
}
