import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/category.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/activity_post.dart';
import 'activities_api.dart';
import 'activities_repository.dart';

typedef NearbyQuery = ({
  double lat,
  double lng,
  double radiusKm,
  int? categoryId,
});

final activitiesApiProvider = Provider(
  (ref) => ActivitiesApi(ref.watch(dioClientProvider).dio),
);
final activitiesRepositoryProvider = Provider(
  (ref) => ActivitiesRepository(ref.watch(activitiesApiProvider)),
);

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(activitiesRepositoryProvider).fetchCategories();
});

/// Currently selected category filter on the Home feed. `null` = All.
class SelectedCategoryFilter extends Notifier<int?> {
  @override
  int? build() => null; // null = "All"

  void select(int? categoryId) => state = categoryId;
}

final selectedCategoryFilterProvider =
    NotifierProvider<SelectedCategoryFilter, int?>(SelectedCategoryFilter.new);

/// Keyed by category id (or null for "all") so switching filters doesn't
/// discard the previous filter's cached results.
final activityFeedProvider = FutureProvider.family<List<ActivityPost>, int?>((
  ref,
  categoryId,
) {
  return ref
      .watch(activitiesRepositoryProvider)
      .fetchActivities(categoryId: categoryId);
});

final activityDetailProvider = FutureProvider.family<ActivityPost, String>((
  ref,
  id,
) {
  return ref.watch(activitiesRepositoryProvider).fetchActivityDetail(id);
});

final myActivitiesProvider = FutureProvider<List<ActivityPost>>((ref) {
  return ref.watch(activitiesRepositoryProvider).fetchMyActivities();
});

final nearbyActivitiesProvider = FutureProvider.autoDispose
    .family<List<ActivityPost>, NearbyQuery>((ref, q) {
      return ref
          .watch(activitiesRepositoryProvider)
          .fetchNearbyActivities(
            lat: q.lat,
            lng: q.lng,
            radiusKm: q.radiusKm,
            categoryId: q.categoryId,
          );
    });
