import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../groups/data/groups_providers.dart';
import '../../groups/domain/group_expense.dart';
import '../../groups/domain/group_roster.dart';

class _ExpenseFormResult {
  final String description;
  final String amount;
  final bool customSplit;
  final bool customAmounts;
  final List<String> splitMemberIds;
  final List<ExpenseShareInput> shares;

  const _ExpenseFormResult({
    required this.description,
    required this.amount,
    required this.customSplit,
    required this.customAmounts,
    required this.splitMemberIds,
    required this.shares,
  });
}

int? parseExpenseCents(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  final fraction = parts.length == 2
      ? int.tryParse(parts.last.padRight(2, '0'))
      : 0;
  if (whole == null || fraction == null) return null;
  return whole * 100 + fraction;
}

String _formatExpenseCents(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

class _ExpenseDialog extends StatefulWidget {
  final GroupRoster roster;
  final GroupExpense? expense;

  const _ExpenseDialog({required this.roster, this.expense});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final Set<String> _allMemberIds;
  late final Set<String> _selectedIds;
  late final Map<String, TextEditingController> _shareControllers;
  late bool _customSplit;
  late bool _customAmounts;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _descriptionController = TextEditingController(
      text: expense?.description ?? '',
    );
    _amountController = TextEditingController(text: expense?.amount ?? '');
    _allMemberIds = widget.roster.members.map((member) => member.id).toSet();
    final initialShares = expense?.shares ?? const <ExpenseShare>[];
    final initialShareIds = initialShares
        .map((share) => share.memberId)
        .toSet();
    _customSplit =
        expense != null &&
        initialShareIds.isNotEmpty &&
        (!_allMemberIds.containsAll(initialShareIds) ||
            !initialShareIds.containsAll(_allMemberIds));
    final initialShareAmounts = initialShares
        .map((share) => parseExpenseCents(share.amount))
        .toSet();
    _customAmounts = initialShareAmounts.length > 1;
    _customSplit = _customSplit || _customAmounts;
    _selectedIds = {...initialShareIds};
    if (expense == null) _selectedIds.addAll(_allMemberIds);
    _shareControllers = {
      for (final member in widget.roster.members)
        member.id: TextEditingController(
          text:
              initialShares
                  .where((share) => share.memberId == member.id)
                  .firstOrNull
                  ?.amount ??
              '',
        ),
    };
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _activeMemberIds => widget.roster.members
      .where((member) => !_customSplit || _selectedIds.contains(member.id))
      .map((member) => member.id)
      .toList(growable: false);

  void _redistributeSharesEqually() {
    final totalCents = parseExpenseCents(_amountController.text);
    final memberIds = _activeMemberIds;
    if (totalCents == null || memberIds.isEmpty) return;
    final base = totalCents ~/ memberIds.length;
    var remainder = totalCents % memberIds.length;
    for (final memberId in memberIds) {
      final cents = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      _shareControllers[memberId]!.text = _formatExpenseCents(cents);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    return AlertDialog(
      title: Text(expense == null ? 'Add expense' : 'Edit expense'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a description.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    if (_customAmounts &&
                        _activeMemberIds.every(
                          (id) => _shareControllers[id]!.text.trim().isEmpty,
                        )) {
                      setState(_redistributeSharesEqually);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                  ),
                  validator: (value) {
                    final amount = parseExpenseCents(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount greater than zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Choose who shares this expense'),
                  subtitle: const Text(
                    'Off means an equal split among all group members.',
                  ),
                  value: _customSplit,
                  onChanged: (value) => setState(() {
                    _customSplit = value ?? false;
                    if (!_customSplit) _selectedIds.addAll(_allMemberIds);
                    if (_customAmounts) _redistributeSharesEqually();
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Assign a specific amount per person'),
                  subtitle: const Text(
                    'Share amounts must add up to the expense total.',
                  ),
                  value: _customAmounts,
                  onChanged: (value) => setState(() {
                    _customAmounts = value ?? false;
                    if (_customAmounts) {
                      _customSplit = true;
                      _redistributeSharesEqually();
                    }
                  }),
                ),
                if (_customSplit)
                  ...widget.roster.members.map(
                    (member) => Column(
                      children: [
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(member.fullName),
                          secondary: UserAvatar(
                            avatarUrl: member.avatar,
                            radius: 17,
                          ),
                          value: _selectedIds.contains(member.id),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selectedIds.add(member.id);
                            } else {
                              _selectedIds.remove(member.id);
                            }
                            if (_customAmounts) {
                              _redistributeSharesEqually();
                            }
                          }),
                        ),
                        if (_customAmounts && _selectedIds.contains(member.id))
                          Padding(
                            padding: const EdgeInsets.only(left: 56, bottom: 8),
                            child: TextFormField(
                              controller: _shareControllers[member.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: '${member.fullName} share',
                                prefixText: '\$ ',
                              ),
                              validator: (value) {
                                final amount = parseExpenseCents(value ?? '');
                                return amount == null
                                    ? 'Enter a valid share amount.'
                                    : null;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_customSplit && _selectedIds.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select at least one member for the split.'),
                ),
              );
              return;
            }
            final amountCents = parseExpenseCents(_amountController.text);
            final activeMemberIds = _activeMemberIds;
            final shares = <ExpenseShareInput>[];
            if (_customAmounts) {
              if (activeMemberIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Select at least one member for the split.'),
                  ),
                );
                return;
              }
              var sharesTotalCents = 0;
              for (final memberId in activeMemberIds) {
                final shareCents = parseExpenseCents(
                  _shareControllers[memberId]!.text,
                );
                if (shareCents == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a valid amount for every selected member.',
                      ),
                    ),
                  );
                  return;
                }
                sharesTotalCents += shareCents;
                shares.add(
                  ExpenseShareInput(
                    memberId: memberId,
                    amount: _formatExpenseCents(shareCents),
                  ),
                );
              }
              if (sharesTotalCents != amountCents) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The member shares must add up exactly to the expense amount.',
                    ),
                  ),
                );
                return;
              }
            }
            Navigator.pop(
              context,
              _ExpenseFormResult(
                description: _descriptionController.text.trim(),
                amount: _formatExpenseCents(amountCents!),
                customSplit: _customSplit,
                customAmounts: _customAmounts,
                splitMemberIds: activeMemberIds,
                shares: shares,
              ),
            );
          },
          child: Text(expense == null ? 'Add expense' : 'Save changes'),
        ),
      ],
    );
  }
}

Future<void> showExpenseDialog({
  required BuildContext context,
  required WidgetRef ref,
  required GroupRoster roster,
  GroupExpense? expense,
}) async {
  final result = await showDialog<_ExpenseFormResult>(
    context: context,
    builder: (_) => _ExpenseDialog(roster: roster, expense: expense),
  );
  if (result == null || !context.mounted) return;

  try {
    final api = ref.read(groupsApiProvider);
    if (expense == null) {
      await api.createExpense(
        groupId: roster.id,
        description: result.description,
        amount: result.amount,
        splitMemberIds: result.customAmounts
            ? null
            : result.customSplit
            ? result.splitMemberIds
            : null,
        shares: result.customAmounts ? result.shares : null,
      );
    } else {
      final newSplit = result.splitMemberIds.toSet();
      final oldSplit = expense.shares.map((share) => share.memberId).toSet();
      final splitChanged =
          !newSplit.containsAll(oldSplit) || !oldSplit.containsAll(newSplit);
      final descriptionChanged = result.description != expense.description;
      final amountChanged = result.amount != expense.amount;
      final currentShares = {
        for (final share in expense.shares)
          share.memberId: parseExpenseCents(share.amount),
      };
      final sharesChanged =
          currentShares.length != result.shares.length ||
          result.shares.any(
            (share) =>
                currentShares[share.memberId] !=
                parseExpenseCents(share.amount),
          );
      final currentShareAmounts = expense.shares
          .map((share) => parseExpenseCents(share.amount))
          .toSet();
      final currentSharesAreUnequal = currentShareAmounts.length > 1;
      final shouldSendEqualSplit =
          !result.customAmounts && (splitChanged || currentSharesAreUnequal);
      final shouldSendShares =
          result.customAmounts && (amountChanged || sharesChanged);
      if (descriptionChanged ||
          amountChanged ||
          shouldSendEqualSplit ||
          shouldSendShares) {
        await api.updateExpense(
          groupId: roster.id,
          expenseId: expense.id,
          description: descriptionChanged ? result.description : null,
          amount: amountChanged ? result.amount : null,
          splitMemberIds: shouldSendEqualSplit ? result.splitMemberIds : null,
          shares: shouldSendShares ? result.shares : null,
        );
      }
    }
    if (!context.mounted) return;
    ref.invalidate(groupExpensesProvider(roster.id));
    ref.invalidate(groupRosterProvider(roster.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(expense == null ? 'Expense added.' : 'Expense updated.'),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
    }
  }
}
