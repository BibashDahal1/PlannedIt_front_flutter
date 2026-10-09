import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/features/trust/domain/pending_activity_rating.dart';

void main() {
  test('parses pending activity details and all rating targets', () {
    final pending = PendingActivityRating.fromJson({
      'activity_id': 'activity-uuid',
      'activity_title': 'Weekend hike',
      'scheduled_end': '2026-10-06T14:30:00Z',
      'group_id': 'group-uuid',
      'my_role': 'host',
      'ratees': [
        {
          'id': 'user-uuid',
          'full_name': 'Example User',
          'role': 'member',
          'avatar': 'https://example.test/avatar.png',
        },
      ],
    });

    expect(pending.activityId, 'activity-uuid');
    expect(pending.activityTitle, 'Weekend hike');
    expect(pending.scheduledEnd, DateTime.parse('2026-10-06T14:30:00Z'));
    expect(pending.groupId, 'group-uuid');
    expect(pending.myRole, 'host');
    expect(pending.ratees, hasLength(1));
    expect(pending.ratees.single.id, 'user-uuid');
    expect(pending.ratees.single.fullName, 'Example User');
    expect(pending.ratees.single.role, 'member');
    expect(pending.ratees.single.avatar, 'https://example.test/avatar.png');
  });

  test('accepts a missing avatar for a pending ratee', () {
    final ratee = PendingRatee.fromJson({
      'id': 'user-uuid',
      'full_name': 'Example User',
      'role': 'host',
      'avatar': null,
    });

    expect(ratee.avatar, isNull);
  });
}
