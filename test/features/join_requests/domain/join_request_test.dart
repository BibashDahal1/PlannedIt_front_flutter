import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/core/network/api_response.dart';
import 'package:plannedit_app/features/join_requests/domain/join_request.dart';

void main() {
  group('incoming join request responses', () {
    test('parses requests from a paginated results payload', () {
      final requests = parseListResponse(
        {
          'count': 2,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_previous': false,
          'next': null,
          'previous': null,
          'results': [
            {
              'id': 'c8f57ae5-8d27-4fa7-a1d5-0e7aaa86182e',
              'activity_post': '53e9da0b-05bc-45ff-80ec-593b49e94257',
              'activity_title': 'New Basketball game',
              'requester': {
                'id': '7502b7bf-7e17-4e4e-ac55-bf29d7852ca1',
                'full_name': 'Bash King',
                'verification_status': 'basic',
                'trust_tier': 'new',
                'date_joined': '2026-10-05T06:29:37.315949Z',
              },
              'message': '',
              'status': 'pending',
              'decline_reason': '',
              'created_at': '2026-10-05T06:31:05.406606Z',
            },
            {
              'id': 'a5cea239-38b3-460c-a787-89f7f8ece87d',
              'activity_post': '53e9da0b-05bc-45ff-80ec-593b49e94257',
              'activity_title': 'New Basketball game',
              'requester': {
                'id': '0f32eef4-8de6-4f0f-ad09-615c24301572',
                'full_name': 'Chatter',
                'verification_status': 'basic',
                'trust_tier': 'new',
                'date_joined': '2026-09-24T09:05:42.142486Z',
              },
              'message': '',
              'status': 'accepted',
              'decline_reason': '',
              'created_at': '2026-10-03T07:11:32.373798Z',
            },
          ],
        },
        JoinRequest.fromJson,
        resourceName: 'incoming join requests',
      );

      expect(requests, hasLength(2));
      expect(requests.first.id, 'c8f57ae5-8d27-4fa7-a1d5-0e7aaa86182e');
      expect(requests.first.requester?.fullName, 'Bash King');
      expect(requests.first.activityTitle, 'New Basketball game');
      expect(requests.first.status, 'pending');
      expect(requests.last.requester?.fullName, 'Chatter');
      expect(requests.last.status, 'accepted');
    });

    test('parses requests nested under a data envelope', () {
      final requests = parseListResponse(
        {
          'data': {
            'count': 1,
            'results': [
              {
                'id': 'request-1',
                'activity_post': 'activity-1',
                'activity_title': 'Basketball',
                'requester': {
                  'id': 'user-1',
                  'full_name': 'Bash King',
                  'verification_status': 'basic',
                  'trust_tier': 'new',
                  'date_joined': '2026-10-05T06:29:37.315949Z',
                },
                'message': '',
                'status': 'pending',
                'decline_reason': '',
                'created_at': '2026-10-05T06:31:05.406606Z',
              },
            ],
          },
        },
        JoinRequest.fromJson,
        resourceName: 'incoming join requests',
      );

      expect(requests, hasLength(1));
      expect(requests.single.requester?.fullName, 'Bash King');
    });
  });
}
