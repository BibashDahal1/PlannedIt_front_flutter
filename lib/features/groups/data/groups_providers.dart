import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/group_roster.dart';
import '../domain/group_summary.dart';
import '../domain/group_expense.dart';
import 'groups_api.dart';

final groupsApiProvider = Provider(
  (ref) => GroupsApi(ref.watch(dioClientProvider).dio),
);

final myGroupsProvider = FutureProvider<List<GroupSummary>>((ref) {
  return ref.watch(groupsApiProvider).fetchMyGroups();
});

final groupRosterProvider = FutureProvider.family<GroupRoster, String>((
  ref,
  groupId,
) {
  return ref.watch(groupsApiProvider).fetchGroup(groupId);
});

final groupExpensesProvider =
    FutureProvider.family<List<GroupExpense>, String>((ref, groupId) {
      return ref.watch(groupsApiProvider).fetchExpenses(groupId);
    });
