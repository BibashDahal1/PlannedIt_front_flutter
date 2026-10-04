import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/group_summary.dart';
import '../domain/group_roster.dart';
import '../domain/group_team.dart';
import '../domain/group_expense.dart';

class GroupsApi {
  GroupsApi(this._dio);
  final Dio _dio;

  Future<List<GroupSummary>> fetchMyGroups() async {
    final response = await _dio.get(ApiEndpoints.myGroups);
    return (response.data as List)
        .map((item) => GroupSummary.fromJson(item as Map<String, dynamic>))
        .toList();
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

  Future<List<GroupExpense>> fetchExpenses(String groupId) async {
    final response = await _dio.get(ApiEndpoints.groupExpenses(groupId));
    final data = response.data;
    final expenses = data is List
        ? data
        : data is Map<String, dynamic> && data['expenses'] is List
        ? data['expenses'] as List
        : throw FormatException('Unexpected expenses response');
    return expenses
        .map(
          (expense) => GroupExpense.fromJson(expense as Map<String, dynamic>),
        )
        .toList(growable: false);
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
