import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/date_utils.dart' as date_utils;
import 'smart_provider.dart';

/// 연속 달성(Streak) 일수 계산
/// 오늘부터 역순으로 각 날짜에 완료된 할일이 1개 이상인지 확인
final streakProvider = Provider<int>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  if (todos.isEmpty) return 0;

  // completedAt 기준으로 날짜별 완료 여부 수집
  final completionDates = <DateTime>{};
  for (final todo in todos) {
    if (todo.completedAt != null) {
      completionDates.add(date_utils.normalizeDate(todo.completedAt!));
    }
  }

  // 오늘부터 역순으로 연속 일수 계산
  int streak = 0;
  var checkDate = date_utils.normalizeDate(DateTime.now());
  while (completionDates.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }
  return streak;
});

/// 스트릭 위험 여부 (오늘 아직 완료한 게 없는데 어제까지 연속 달성 중)
final streakAtRiskProvider = Provider<bool>((ref) {
  final todayCompleted = ref.watch(smartTodayCompletedTodosProvider);
  final streak = ref.watch(streakProvider);
  return streak == 0 && todayCompleted.isEmpty && _yesterdayStreak(ref) > 0;
});

int _yesterdayStreak(Ref ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  if (todos.isEmpty) return 0;

  final completionDates = <DateTime>{};
  for (final todo in todos) {
    if (todo.completedAt != null) {
      completionDates.add(date_utils.normalizeDate(todo.completedAt!));
    }
  }

  int streak = 0;
  var checkDate = date_utils.normalizeDate(DateTime.now()).subtract(const Duration(days: 1));
  while (completionDates.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }
  return streak;
}
