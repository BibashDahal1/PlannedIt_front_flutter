import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/public_profile.dart';
import '../domain/rating.dart';

class TrustApi {
  TrustApi(this._dio);
  final Dio _dio;

  Future<void> completeActivity(String activityId) async {
    await _dio.post(ApiEndpoints.activityComplete(activityId));
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
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
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
