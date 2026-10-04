class ExpenseShare {
  final String memberId;
  final String memberName;
  final String amount;

  const ExpenseShare({
    required this.memberId,
    required this.memberName,
    required this.amount,
  });

  factory ExpenseShare.fromJson(Map<String, dynamic> json) => ExpenseShare(
    memberId: json['member_id'] as String,
    memberName: json['member_name'] as String? ?? '',
    amount: json['amount'].toString(),
  );
}

class ExpenseShareInput {
  final String memberId;
  final String amount;

  const ExpenseShareInput({required this.memberId, required this.amount});

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'amount': amount,
  };
}

class GroupExpense {
  final String id;
  final String description;
  final String amount;
  final String paidById;
  final String paidByName;
  final List<ExpenseShare> shares;
  final DateTime createdAt;

  const GroupExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidById,
    required this.paidByName,
    required this.shares,
    required this.createdAt,
  });

  factory GroupExpense.fromJson(Map<String, dynamic> json) => GroupExpense(
    id: json['id'] as String,
    description: json['description'] as String? ?? '',
    amount: json['amount'].toString(),
    paidById: json['paid_by_id'] as String,
    paidByName: json['paid_by_name'] as String? ?? '',
    shares: (json['shares'] as List? ?? const [])
        .map((share) => ExpenseShare.fromJson(share as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
