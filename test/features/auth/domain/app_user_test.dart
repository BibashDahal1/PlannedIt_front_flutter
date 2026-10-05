import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/features/auth/domain/app_user.dart';

void main() {
  test('parses editable contact, birth date, and social profile fields', () {
    final user = AppUser.fromJson({
      'id': 'user-1',
      'phone_number': '+9779842532066',
      'email': 'person@example.com',
      'full_name': 'Plans It',
      'date_of_birth': '1990-04-20',
      'avatar': null,
      'verification_status': 'verified',
      'trust_tier': 'trusted',
      'is_phone_verified': true,
      'date_joined': '2026-09-24T14:52:23.195144Z',
      'social_profiles': [
        {
          'platform': 'instagram',
          'username': 'your_handle',
          'profile_url': 'https://www.instagram.com/your_handle/',
        },
        {'platform': 'linkedin', 'username': 'your_name'},
      ],
    });

    expect(user.email, 'person@example.com');
    expect(user.dateOfBirth, DateTime(1990, 4, 20));
    expect(user.socialProfiles, hasLength(2));
    expect(user.socialProfiles.first.platform, 'instagram');
    expect(user.socialProfiles.first.username, 'your_handle');
    expect(
      user.socialProfiles.first.profileUrl,
      'https://www.instagram.com/your_handle/',
    );
    expect(user.socialProfiles.last.profileUrl, isNull);
  });
}
