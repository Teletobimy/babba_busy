import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/date_utils.dart' as date_utils;
import 'smart_provider.dart';

/// 날짜별 지출 합계 (캘린더 표시용)
final dailyExpenseProvider = Provider<Map<DateTime, int>>((ref) {
  final transactions = ref.watch(smartTransactionsProvider);
  final map = <DateTime, int>{};

  for (final tx in transactions) {
    if (tx.type != 'expense') continue;
    final date = date_utils.normalizeDate(tx.date);
    map[date] = (map[date] ?? 0) + tx.amount;
  }

  return map;
});
