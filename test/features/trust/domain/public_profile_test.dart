import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/features/trust/domain/public_profile.dart';

void main() {
  test('parses public rating aggregates from the public profile response', () {
    final profile = PublicProfile.fromJson({
      'id': 'user-uuid',
      'full_name': 'Example User',
      'verification_status': 'social',
      'trust_tier': 'new',
      'average_rating': 4.5,
      'ratings_count': 2,
      'activities_hosted': 3,
      'date_joined': '2026-09-24T14:52:23Z',
    });

    expect(profile.averageRating, 4.5);
    expect(profile.ratingsCount, 2);
  });

  test('keeps the rating empty when the public profile has no ratings', () {
    final profile = PublicProfile.fromJson({
      'id': 'user-uuid',
      'full_name': 'Example User',
      'verification_status': 'social',
      'trust_tier': 'new',
      'average_rating': null,
      'ratings_count': 0,
      'activities_hosted': 0,
      'date_joined': '2026-09-24T14:52:23Z',
    });

    expect(profile.averageRating, isNull);
    expect(profile.ratingsCount, 0);
  });
}
