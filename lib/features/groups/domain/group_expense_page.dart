import 'group_expense.dart';

class GroupExpensePage {
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final String? next;
  final String? previous;
  final List<GroupExpense> results;

  const GroupExpensePage({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    required this.next,
    required this.previous,
    required this.results,
  });

  factory GroupExpensePage.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    if (rawResults is! List) {
      throw const FormatException('Unexpected paginated expenses response');
    }

    return GroupExpensePage(
      count: _requiredInt(json, 'count'),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'page_size'),
      totalPages: _requiredInt(json, 'total_pages'),
      hasNext: _requiredBool(json, 'has_next'),
      hasPrevious: _requiredBool(json, 'has_previous'),
      next: _optionalString(json, 'next'),
      previous: _optionalString(json, 'previous'),
      results: rawResults
          .map(
            (expense) => GroupExpense.fromJson(
              Map<String, dynamic>.from(expense as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  factory GroupExpensePage.fromLegacyResults(
    List<dynamic> expenses, {
    required int page,
    required int pageSize,
  }) {
    final results = expenses
        .map(
          (expense) => GroupExpense.fromJson(
            Map<String, dynamic>.from(expense as Map),
          ),
        )
        .toList(growable: false);
    return GroupExpensePage(
      count: results.length,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
      hasNext: false,
      hasPrevious: false,
      next: null,
      previous: null,
      results: results,
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid pagination field "$key"');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid pagination field "$key"');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('Invalid pagination field "$key"');
  }
  return value as String?;
}
