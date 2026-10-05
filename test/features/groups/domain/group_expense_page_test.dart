import 'package:flutter_test/flutter_test.dart';
import 'package:plannedit_app/features/groups/domain/group_expense_page.dart';

void main() {
  group('GroupExpensePage.fromJson', () {
    test('parses backend pagination metadata and expense results', () {
      final page = GroupExpensePage.fromJson({
        'count': 47,
        'page': 2,
        'page_size': 20,
        'total_pages': 3,
        'has_next': true,
        'has_previous': true,
        'next': 'https://api.example.com/api/v1/expenses?page=3',
        'previous': 'https://api.example.com/api/v1/expenses?page=1',
        'results': [
          {
            'id': 'expense-1',
            'description': 'Dinner',
            'amount': '20.00',
            'paid_by_id': 'member-1',
            'paid_by_name': 'Alex',
            'shares': [],
            'created_at': '2026-10-04T10:00:00Z',
          },
        ],
      });

      expect(page.count, 47);
      expect(page.page, 2);
      expect(page.pageSize, 20);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
      expect(page.hasPrevious, isTrue);
      expect(page.next, contains('page=3'));
      expect(page.previous, contains('page=1'));
      expect(page.results, hasLength(1));
      expect(page.results.single.description, 'Dinner');
    });

    test('rejects responses without required pagination metadata', () {
      expect(
        () => GroupExpensePage.fromJson({'results': []}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
