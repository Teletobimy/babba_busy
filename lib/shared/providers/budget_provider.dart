import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 거래 목록 스트림
final transactionsProvider = StreamProvider<List<BudgetTransaction>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => BudgetTransaction.fromFirestore(doc)).toList());
});

/// 이번 달 거래 목록
final thisMonthTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  return transactions.where((t) {
    return t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
           t.date.isBefore(endOfMonth.add(const Duration(seconds: 1)));
  }).toList();
});

/// 이번 달 요약
final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final transactions = ref.watch(thisMonthTransactionsProvider);

  int totalIncome = 0;
  int totalExpense = 0;
  Map<String, int> categoryExpenses = {};

  for (final t in transactions) {
    if (t.isIncome) {
      totalIncome += t.amount;
    } else {
      totalExpense += t.amount;
      categoryExpenses[t.category] = 
          (categoryExpenses[t.category] ?? 0) + t.amount;
    }
  }

  return MonthSummary(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    balance: totalIncome - totalExpense,
    categoryExpenses: categoryExpenses,
  );
});

/// 고정 지출 목록
final recurringTransactionsProvider = Provider<List<BudgetTransaction>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  return transactions.where((t) => t.isRecurring).toList();
});

/// 카테고리별 거래 목록
final transactionsByCategoryProvider = 
    Provider.family<List<BudgetTransaction>, String>((ref, category) {
  final transactions = ref.watch(thisMonthTransactionsProvider);
  return transactions.where((t) => t.category == category).toList();
});

/// 월 요약 모델
class MonthSummary {
  final int totalIncome;
  final int totalExpense;
  final int balance;
  final Map<String, int> categoryExpenses;

  MonthSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryExpenses,
  });

  /// 카테고리별 비율 (%)
  double getCategoryPercentage(String category) {
    if (totalExpense == 0) return 0;
    return ((categoryExpenses[category] ?? 0) / totalExpense) * 100;
  }
}

/// 가계부 서비스
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService(ref);
});

class BudgetService {
  final Ref _ref;

  BudgetService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);

  String? get _familyId => _ref.read(currentMembershipProvider)?.groupId;
  String? get _userId => _ref.read(currentUserProvider)?.uid;

  CollectionReference? get _transactionsRef {
    if (_familyId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_familyId).collection('transactions');
  }

  /// 거래 추가
  Future<void> addTransaction({
    required String type,
    required int amount,
    required String category,
    String? memo,
    required DateTime date,
    bool isRecurring = false,
    String? recurringType,
  }) async {
    final transactionsRef = _transactionsRef;
    if (transactionsRef == null || _userId == null) return;

    await transactionsRef.add({
      'familyId': _familyId,
      'type': type,
      'amount': amount,
      'category': category,
      'memo': memo,
      'date': Timestamp.fromDate(date),
      'userId': _userId,
      'isRecurring': isRecurring,
      'recurringType': recurringType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 거래 수정
  Future<void> updateTransaction(String transactionId, {
    String? type,
    int? amount,
    String? category,
    String? memo,
    DateTime? date,
    bool? isRecurring,
    String? recurringType,
  }) async {
    final transactionsRef = _transactionsRef;
    if (transactionsRef == null) return;
    
    final updates = <String, dynamic>{};
    if (type != null) updates['type'] = type;
    if (amount != null) updates['amount'] = amount;
    if (category != null) updates['category'] = category;
    if (memo != null) updates['memo'] = memo;
    if (date != null) updates['date'] = Timestamp.fromDate(date);
    if (isRecurring != null) updates['isRecurring'] = isRecurring;
    if (recurringType != null) updates['recurringType'] = recurringType;

    if (updates.isNotEmpty) {
      await transactionsRef.doc(transactionId).update(updates);
    }
  }

  /// 거래 삭제
  Future<void> deleteTransaction(String transactionId) async {
    final transactionsRef = _transactionsRef;
    if (transactionsRef == null) return;
    await transactionsRef.doc(transactionId).delete();
  }
}
