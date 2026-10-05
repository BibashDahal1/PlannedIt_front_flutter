import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/core/network/api_response.dart';
import 'package:plannedit_app/features/activities/domain/activity_post.dart';
import 'package:plannedit_app/features/chat/domain/chat_message.dart';
import 'package:plannedit_app/features/groups/domain/group_summary.dart';

void main() {
  group('parseListResponse', () {
    test('reads results from the standard paginated response', () {
      final results = parseListResponse(
        {
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_previous': false,
          'next': null,
          'previous': null,
          'results': [
            {'id': 1, 'name': 'Futsal'},
          ],
        },
        (json) => json['name'] as String,
        resourceName: 'categories',
      );

      expect(results, ['Futsal']);
    });

    test('continues to accept legacy unpaginated lists', () {
      final results = parseListResponse(
        [
          {'id': 1, 'name': 'Futsal'},
        ],
        (json) => json['name'] as String,
        resourceName: 'categories',
      );

      expect(results, ['Futsal']);
    });

    test('parses paginated activity results using the activity model', () {
      final activities = parseListResponse(
        {
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_previous': false,
          'next': null,
          'previous': null,
          'results': [
            {
              'id': '4cb7c4c7-f39d-47d9-845e-045adb1cd728',
              'title': 'Futsal',
              'category': {'id': 1, 'name': 'Futsal', 'icon': 'sports_soccer'},
              'host': {
                'id': 'e687088b-2883-4b71-8bcf-31d1561ad395',
                'full_name': 'Plans It',
                'trust_tier': 'new',
                'verification_status': 'basic',
              },
              'location': {
                'latitude': 26.468641649534433,
                'longitude': 87.28110237329163,
                'address_text': '',
                'venue_name': '',
              },
              'total_spots_needed': 4,
              'team_size': null,
              'cost_sharing_enabled': false,
              'scheduled_start': '2026-09-26T13:49:00Z',
              'scheduled_end': '2026-10-31T13:49:00Z',
              'status': 'open',
            },
          ],
        },
        ActivityPost.fromJson,
        resourceName: 'activities',
      );

      expect(activities, hasLength(1));
      expect(activities.single.title, 'Futsal');
      expect(activities.single.category.name, 'Futsal');
      expect(activities.single.teamSize, isNull);
    });

    test('parses paginated groups used by the Chats tab', () {
      final groups = parseListResponse(
        {
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_previous': false,
          'next': null,
          'previous': null,
          'results': [
            {
              'id': 'group-1',
              'activity_title': 'Basketball',
              'members': [
                {'full_name': 'Alex'},
              ],
            },
          ],
        },
        GroupSummary.fromJson,
        resourceName: 'groups',
      );

      expect(groups, hasLength(1));
      expect(groups.single.activityTitle, 'Basketball');
      expect(groups.single.memberNames, ['Alex']);
    });

    test('parses paginated chat history using the chat message model', () {
      final messages = parseListResponse(
        {
          'count': 1,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_previous': false,
          'next': null,
          'previous': null,
          'results': [
            {
              'id': 'message-1',
              'sender_id': 'user-1',
              'sender_name': 'Alex',
              'content': 'See you there',
              'created_at': '2026-10-04T10:00:00Z',
            },
          ],
        },
        ChatMessage.fromJson,
        resourceName: 'chat messages',
      );

      expect(messages, hasLength(1));
      expect(messages.single.content, 'See you there');
    });

    test('reports an unexpected response shape instead of hiding it', () {
      expect(
        () => parseListResponse(
          {'count': 0},
          (json) => json,
          resourceName: 'activities',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
