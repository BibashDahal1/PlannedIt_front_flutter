import '../../../shared/models/category.dart';
import '../domain/activity_post.dart';
import '../domain/create_activity_input.dart';
import 'activities_api.dart';
import '../domain/update_activity_input.dart';

class ActivitiesRepository {
  ActivitiesRepository(this._api);
  final ActivitiesApi _api;

  Future<List<Category>> fetchCategories() => _api.fetchCategories();
  Future<String> createActivity(CreateActivityInput input) =>
      _api.createActivity(input);
  Future<List<ActivityPost>> fetchActivities({int? categoryId}) =>
      _api.fetchActivities(categoryId: categoryId);
  Future<ActivityPost> fetchActivityDetail(String id) =>
      _api.fetchActivityDetail(id);
  Future<List<ActivityPost>> fetchMyActivities() => _api.fetchMyActivities();
  Future<ActivityPost> updateActivity(String id, UpdateActivityInput input) =>
      _api.updateActivity(id, input);
  Future<ActivityPost> cancelActivity(String id) => _api.cancelActivity(id);
  Future<void> deleteActivity(String id) => _api.deleteActivity(id);

  Future<List<ActivityPost>> fetchNearbyActivities({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int? categoryId,
  }) => _api.fetchNearbyActivities(
    lat: lat,
    lng: lng,
    radiusKm: radiusKm,
    categoryId: categoryId,
  );
}
