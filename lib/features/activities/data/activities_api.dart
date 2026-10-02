import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/models/category.dart';
import '../domain/activity_post.dart';
import '../domain/create_activity_input.dart';
import '../domain/update_activity_input.dart';

class ActivitiesApi {
  ActivitiesApi(this._dio);
  final Dio _dio;

  Future<List<Category>> fetchCategories() async {
    final response = await _dio.get(ApiEndpoints.categories);
    return (response.data as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createActivity(CreateActivityInput input) async {
    final response = await _dio.post(
      ApiEndpoints.activities,
      data: input.toJson(),
    );
    return response.data['id'] as String;
  }

  Future<List<ActivityPost>> fetchActivities({int? categoryId}) async {
    final response = await _dio.get(
      ApiEndpoints.activities,
      queryParameters: categoryId != null ? {'category': categoryId} : null,
    );
    return (response.data as List)
        .map((e) => ActivityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActivityPost> fetchActivityDetail(String id) async {
    final response = await _dio.get(ApiEndpoints.activityDetail(id));
    return ActivityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ActivityPost>> fetchMyActivities() async {
    final response = await _dio.get(ApiEndpoints.myActivities);
    return (response.data as List)
        .map(
          (e) => ActivityPost.fromJson(
            e as Map<String, dynamic>,
            exactLocation: true,
          ),
        )
        .toList();
  }

  Future<ActivityPost> updateActivity(
    String id,
    UpdateActivityInput input,
  ) async {
    final response = await _dio.patch(
      ApiEndpoints.activityDetail(id),
      data: input.toJson(),
    );
    return ActivityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActivityPost> cancelActivity(String id) async {
    final response = await _dio.post(ApiEndpoints.activityCancel(id));
    return ActivityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteActivity(String id) async {
    await _dio.delete(ApiEndpoints.activityDetail(id));
  }

  Future<List<ActivityPost>> fetchNearbyActivities({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int? categoryId,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.activitiesNearby,
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (categoryId != null) 'category': categoryId,
      },
    );
    return (response.data as List)
        .map((e) => ActivityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
