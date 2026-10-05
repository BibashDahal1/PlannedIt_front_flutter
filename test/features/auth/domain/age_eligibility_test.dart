import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/features/auth/domain/age_eligibility.dart';

void main() {
  group('isAtLeast18', () {
    test('allows a user on their 18th birthday', () {
      expect(
        isAtLeast18(DateTime(2008, 10, 4), today: DateTime(2026, 10, 4)),
        isTrue,
      );
    });

    test('does not allow a user one day before their 18th birthday', () {
      expect(
        isAtLeast18(DateTime(2008, 10, 5), today: DateTime(2026, 10, 4)),
        isFalse,
      );
    });

    test('treats a February 29 birthday as reached on March 1', () {
      expect(
        isAtLeast18(DateTime(2008, 2, 29), today: DateTime(2026, 2, 28)),
        isFalse,
      );
      expect(
        isAtLeast18(DateTime(2008, 2, 29), today: DateTime(2026, 3, 1)),
        isTrue,
      );
    });
  });
}
