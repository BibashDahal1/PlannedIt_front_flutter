import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../activities/data/activities_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/groups_providers.dart';
import '../../groups/domain/group_expense.dart';
import '../../groups/domain/group_member.dart';
import 'dashboard_widgets.dart';
import 'expense_dialog.dart';

class CostManagementTab extends ConsumerWidget {
  final String groupId;
  final bool isActive;

  const CostManagementTab({
    super.key,
    required this.groupId,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isActive) return const SizedBox.shrink();

    // Start the expense request immediately when the user opens this tab;
    // it does not depend on a separate activity-detail request.
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final rosterAsync = ref.watch(groupRosterProvider(groupId));
    return rosterAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DashboardError(
        message: 'Could not load group: ${extractApiErrorMessage(error)}',
        onRetry: () => ref.invalidate(groupRosterProvider(groupId)),
      ),
      data: (roster) {
        final activityAsync = ref.watch(
          activityDetailProvider(roster.activityId),
        );
        final costSharingEnabled =
            activityAsync.value?.costSharingEnabled ?? false;
        final currentUserId = ref.watch(authControllerProvider).value?.user?.id;
        final isHost = roster.members.any(
          (member) =>
              member.id == currentUserId && member.role.toLowerCase() == 'host',
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Shared costs',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: costSharingEnabled
                        ? () => showExpenseDialog(
                            context: context,
                            ref: ref,
                            roster: roster,
                          )
                        : null,
                    icon: const SketchIcon('plus', size: 22),
                    label: const Text('Add expense'),
                  ),
                ],
              ),
              if (activityAsync.hasError)
                SketchBox(
                  seed: roster.id.hashCode,
                  radius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Could not check activity cost settings.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(extractApiErrorMessage(activityAsync.error!)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Retry activity settings',
                        onPressed: () => ref.invalidate(
                          activityDetailProvider(roster.activityId),
                        ),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                )
              else if (activityAsync.isLoading && !activityAsync.hasValue)
                const LinearProgressIndicator()
              else if (activityAsync.hasValue && !costSharingEnabled)
                SketchBox(
                  seed: roster.id.hashCode + 1,
                  radius: 16,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SketchIcon('calendar', size: 26),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Shared costs are off. The activity host can enable them in Activity settings.',
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push('/activity/${roster.activityId}'),
                        child: const Text('Activity'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                '${roster.members.length} group members · expenses are split across the selected members',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: expensesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => DashboardError(
                    message:
                        'Could not load expenses: ${extractApiErrorMessage(error)}',
                    onRetry: () =>
                        ref.invalidate(groupExpensesProvider(groupId)),
                  ),
                  data: (expenses) => expenses.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () async =>
                              ref.invalidate(groupExpensesProvider(groupId)),
                          child: ListView(
                            padding: const EdgeInsets.only(top: 48),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Center(
                                child: SketchBox(
                                  seed: groupId.hashCode,
                                  radius: 16,
                                  padding: const EdgeInsets.all(20),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SketchIcon('people', size: 28),
                                      SizedBox(width: 10),
                                      Text('No shared expenses yet.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _ExpenseSummary(
                              expenses: expenses,
                              members: roster.members,
                              currentUserId: currentUserId,
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () async => ref.invalidate(
                                  groupExpensesProvider(groupId),
                                ),
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: expenses.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final expense = expenses[index];
                                    final canEdit =
                                        expense.paidById == currentUserId ||
                                        isHost;
                                    return _ExpenseCard(
                                      expense: expense,
                                      canEdit: canEdit,
                                      onEdit: () => showExpenseDialog(
                                        context: context,
                                        ref: ref,
                                        roster: roster,
                                        expense: expense,
                                      ),
                                      onDelete: () => _deleteExpense(
                                        context: context,
                                        ref: ref,
                                        groupId: roster.id,
                                        expense: expense,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseSummary extends StatelessWidget {
  final List<GroupExpense> expenses;
  final List<GroupMember> members;
  final String? currentUserId;

  const _ExpenseSummary({
    required this.expenses,
    required this.members,
    required this.currentUserId,
  });

  int _cents(String value) {
    return parseExpenseCents(value) ?? 0;
  }

  String _formatCents(int value) =>
      '\$${(value.abs() ~/ 100)}.${(value.abs() % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final memberIds = members.map((member) => member.id).toSet();
    final balances = <String, int>{for (final id in memberIds) id: 0};
    var totalCents = 0;
    var hasCompleteShareDetails = true;
    for (final expense in expenses) {
      final amount = _cents(expense.amount);
      totalCents += amount;
      final sharesCents = expense.shares.fold<int>(
        0,
        (total, share) => total + _cents(share.amount),
      );
      if (expense.shares.isEmpty ||
          sharesCents != amount ||
          expense.shares.any((share) => !memberIds.contains(share.memberId))) {
        hasCompleteShareDetails = false;
      }
      if (balances.containsKey(expense.paidById)) {
        balances.update(expense.paidById, (balance) => balance + amount);
      }
      for (final share in expense.shares) {
        if (balances.containsKey(share.memberId)) {
          balances.update(
            share.memberId,
            (balance) => balance - _cents(share.amount),
          );
        }
      }
    }
    final currentBalance = currentUserId == null || !hasCompleteShareDetails
        ? null
        : balances[currentUserId];
    final personalDescription = currentBalance == null
        ? currentUserId == null
              ? 'Sign in to view your balance'
              : 'Balance details unavailable'
        : currentBalance > 0
        ? 'You are owed ${_formatCents(currentBalance)}'
        : currentBalance < 0
        ? 'You owe ${_formatCents(currentBalance)}'
        : 'You are settled up';

    return SketchBox(
      seed: expenses.length,
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total expenses',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCents(totalCents),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your balance',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  personalDescription,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final GroupExpense expense;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SketchBox(
      seed: expense.id.hashCode,
      radius: 16,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: SketchBox(
          seed: expense.id.hashCode + 1,
          radius: 12,
          width: 44,
          height: 44,
          child: const Center(child: Icon(Icons.receipt_outlined)),
        ),
        title: Text(expense.description),
        subtitle: Text(
          'Paid by ${expense.paidByName} · ${_formatExpenseDate(expense.createdAt)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${expense.amount}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                tooltip: 'Expense actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
        children: [
          if (expense.shares.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Text('No split details returned.'),
            )
          else
            ...expense.shares.map(
              (share) => Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(share.memberName)),
                    Text('\$${share.amount}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatExpenseDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

Future<void> _deleteExpense({
  required BuildContext context,
  required WidgetRef ref,
  required String groupId,
  required GroupExpense expense,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this expense?'),
      content: Text('“${expense.description}” will be permanently removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final api = ref.read(groupsApiProvider);
    await api.deleteExpense(groupId: groupId, expenseId: expense.id);
    if (!context.mounted) return;
    ref.invalidate(groupExpensesProvider(groupId));
    ref.invalidate(groupRosterProvider(groupId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
    }
  }
}
