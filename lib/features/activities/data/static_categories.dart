import '../../../shared/models/category.dart';

/// Hardcoded to match the closed category list from the API spec
/// (GET /api/v1/categories) exactly -- same ids, names, and icon keys.
/// If/when that endpoint is confirmed live on the backend, swap
/// categoriesProvider back to ActivitiesApi.fetchCategories() instead
/// of deleting this file; the ids must stay in sync either way since
/// POST /activities sends category as this integer id.
const List<Category> staticCategories = [
  Category(id: 1, name: 'Futsal', iconKey: 'sports_soccer'),
  Category(id: 2, name: 'Basketball', iconKey: 'sports_basketball'),
  Category(id: 3, name: 'Hiking', iconKey: 'hiking'),
  Category(id: 4, name: 'Board Games', iconKey: 'casino'),
  Category(id: 5, name: 'Study Group', iconKey: 'school'),
  Category(id: 6, name: 'Volunteering', iconKey: 'volunteer_activism'),
  Category(id: 7, name: 'Other', iconKey: 'more_horiz'),
];
