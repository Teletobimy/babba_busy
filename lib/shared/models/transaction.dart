import 'package:cloud_firestore/cloud_firestore.dart';

/// 거래(수입/지출) 모델
class BudgetTransaction {
  final String id;
  final String familyId;
  final String type; // 'income' or 'expense'
  final int amount;
  final String category;
  final String? memo;
  final DateTime date;
  final String userId;
  final bool isRecurring;
  final String? recurringType; // 'monthly', 'yearly'
  final DateTime createdAt;

  BudgetTransaction({
    required this.id,
    required this.familyId,
    required this.type,
    required this.amount,
    required this.category,
    this.memo,
    required this.date,
    required this.userId,
    this.isRecurring = false,
    this.recurringType,
    required this.createdAt,
  });

  factory BudgetTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetTransaction(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      type: data['type'] ?? 'expense',
      amount: data['amount'] ?? 0,
      category: data['category'] ?? 'other',
      memo: data['memo'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
      isRecurring: data['isRecurring'] ?? false,
      recurringType: data['recurringType'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'type': type,
      'amount': amount,
      'category': category,
      'memo': memo,
      'date': Timestamp.fromDate(date),
      'userId': userId,
      'isRecurring': isRecurring,
      'recurringType': recurringType,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  BudgetTransaction copyWith({
    String? id,
    String? familyId,
    String? type,
    int? amount,
    String? category,
    String? memo,
    DateTime? date,
    String? userId,
    bool? isRecurring,
    String? recurringType,
    DateTime? createdAt,
  }) {
    return BudgetTransaction(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      memo: memo ?? this.memo,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}

/// 카테고리 상수
class TransactionCategory {
  static const String food = 'food';
  static const String transport = 'transport';
  static const String shopping = 'shopping';
  static const String entertainment = 'entertainment';
  static const String health = 'health';
  static const String education = 'education';
  static const String housing = 'housing';
  static const String utilities = 'utilities';
  static const String income = 'income';
  static const String other = 'other';

  static const Map<String, String> labels = {
    food: '식비',
    transport: '교통',
    shopping: '쇼핑',
    entertainment: '여가',
    health: '건강',
    education: '교육',
    housing: '주거',
    utilities: '공과금',
    income: '수입',
    other: '기타',
  };

  static String getLabel(String category) {
    return labels[category] ?? '기타';
  }

  static List<String> get expenseCategories => [
    food, transport, shopping, entertainment, health, education, housing, utilities, other
  ];

  static List<String> get incomeCategories => [income];
}
