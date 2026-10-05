import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/group_summary.dart';
import '../domain/group_roster.dart';
import '../domain/group_team.dart';
import '../domain/group_expense.dart';
import '../domain/group_expense_page.dart';

class GroupsApi {
  GroupsApi(this._dio);
  final Dio _dio;

  Future<List<GroupSummary>> fetchMyGroups() async {
    final response = await _dio.get(ApiEndpoints.myGroups);
    return parseListResponse(
      response.data,
      GroupSummary.fromJson,
      resourceName: 'groups',
    );
  }

  Future<GroupRoster> fetchGroup(String id) async {
    final response = await _dio.get(ApiEndpoints.groupDetail(id));
    return GroupRoster.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupRoster> updateTeams(String groupId, List<GroupTeam> teams) async {
    final response = await _dio.put(
      ApiEndpoints.groupTeams(groupId),
      data: {
        'teams': teams.map((team) => team.toJson()).toList(growable: false),
        'confirmed': true,
      },
    );
    return GroupRoster.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupExpensePage> fetchExpenses(
    String groupId, {
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.groupExpenses(groupId),
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = response.data;
    if (data is List) {
      return GroupExpensePage.fromLegacyResults(
        data,
        page: page,
        pageSize: pageSize,
      );
    }
    if (data is Map) {
      final json = Map<String, dynamic>.from(data);
      if (json['results'] is List) {
        return GroupExpensePage.fromJson(json);
      }
      if (json['expenses'] is List) {
        return GroupExpensePage.fromLegacyResults(
          json['expenses'] as List<dynamic>,
          page: page,
          pageSize: pageSize,
        );
      }
    }
    throw const FormatException('Unexpected expenses response');
  }

  Future<GroupExpense> createExpense({
    required String groupId,
    required String description,
    required String amount,
    List<String>? splitMemberIds,
    List<ExpenseShareInput>? shares,
  }) async {
    if (splitMemberIds != null && shares != null) {
      throw ArgumentError(
        'An expense cannot use both equal-split members and custom shares.',
      );
    }
    final response = await _dio.post(
      ApiEndpoints.groupExpenses(groupId),
      data: {
        'description': description,
        'amount': amount,
        'split_member_ids': ?splitMemberIds,
        'shares': ?shares?.map((share) => share.toJson()).toList(),
      },
    );
    return GroupExpense.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GroupExpense> updateExpense({
    required String groupId,
    required String expenseId,
    String? description,
    String? amount,
    List<String>? splitMemberIds,
    List<ExpenseShareInput>? shares,
  }) async {
    if (splitMemberIds != null && shares != null) {
      throw ArgumentError(
        'An expense cannot use both equal-split members and custom shares.',
      );
    }
    final changes = <String, dynamic>{
      'description': ?description,
      'amount': ?amount,
      'split_member_ids': ?splitMemberIds,
      'shares': ?shares?.map((share) => share.toJson()).toList(),
    };
    if (changes.isEmpty) {
      throw ArgumentError('At least one expense field must be updated.');
    }
    final response = await _dio.patch(
      ApiEndpoints.groupExpense(groupId, expenseId),
      data: changes,
    );
    return GroupExpense.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
  }) async {
    await _dio.delete(ApiEndpoints.groupExpense(groupId, expenseId));
  }
}
