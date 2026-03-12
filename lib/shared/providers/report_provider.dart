import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/date_utils.dart' as date_utils;
import 'smart_provider.dart';

/// 리포트 기간
enum ReportPeriod { week, month }

/// 리포트 기간 선택 provider
final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.week);

/// 일별 완료 수 (최근 7일 또는 30일)
final dailyCompletionProvider = Provider<Map<DateTime, int>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final todos = ref.watch(smartCompletedTodosProvider);
  final days = period == ReportPeriod.week ? 7 : 30;
  final now = date_utils.normalizeDate(DateTime.now());

  final map = <DateTime, int>{};
  for (var i = 0; i < days; i++) {
    final date = now.subtract(Duration(days: i));
    map[date] = 0;
  }

  for (final todo in todos) {
    if (todo.completedAt == null) continue;
    final date = date_utils.normalizeDate(todo.completedAt!);
    if (map.containsKey(date)) {
      map[date] = map[date]! + 1;
    }
  }

  return map;
});

/// 멤버별 완료 수
final memberCompletionProvider = Provider<Map<String, int>>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  final members = ref.watch(smartMembersProvider);

  final map = <String, int>{};
  for (final member in members) {
    map[member.id] = 0;
  }

  for (final todo in todos) {
    for (final member in members) {
      if (todo.isAssignedTo(member.id)) {
        map[member.id] = (map[member.id] ?? 0) + 1;
      }
    }
  }

  return map;
});

/// 요일별 완료 패턴 (0=월, 6=일)
final weekdayPatternProvider = Provider<Map<int, int>>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);

  final map = <int, int>{};
  for (var i = 1; i <= 7; i++) {
    map[i] = 0;
  }

  for (final todo in todos) {
    if (todo.completedAt == null) continue;
    final weekday = todo.completedAt!.weekday; // 1=Mon, 7=Sun
    map[weekday] = (map[weekday] ?? 0) + 1;
  }

  return map;
});

/// 전체 통계 요약
final reportSummaryProvider = Provider<ReportSummary>((ref) {
  final todos = ref.watch(smartCompletedTodosProvider);
  final allTodos = ref.watch(smartTodosProvider);
  final dailyMap = ref.watch(dailyCompletionProvider);

  final totalCompleted = todos.length;
  final totalPending = allTodos.where((t) => !t.isCompleted).length;
  final totalItems = dailyMap.values.fold<int>(0, (sum, v) => sum + v);
  final activeDays = dailyMap.values.where((v) => v > 0).length;
  final avgPerDay = activeDays > 0 ? totalItems / activeDays : 0.0;

  // 가장 생산적인 요일
  final weekdayMap = ref.watch(weekdayPatternProvider);
  var bestDay = 1;
  var bestCount = 0;
  weekdayMap.forEach((day, count) {
    if (count > bestCount) {
      bestDay = day;
      bestCount = count;
    }
  });

  return ReportSummary(
    totalCompleted: totalCompleted,
    totalPending: totalPending,
    avgPerDay: avgPerDay,
    bestWeekday: bestDay,
    bestWeekdayCount: bestCount,
  );
});

class ReportSummary {
  final int totalCompleted;
  final int totalPending;
  final double avgPerDay;
  final int bestWeekday;
  final int bestWeekdayCount;

  const ReportSummary({
    required this.totalCompleted,
    required this.totalPending,
    required this.avgPerDay,
    required this.bestWeekday,
    required this.bestWeekdayCount,
  });

  String get bestWeekdayName {
    const names = {1: '월요일', 2: '화요일', 3: '수요일', 4: '목요일', 5: '금요일', 6: '토요일', 7: '일요일'};
    return names[bestWeekday] ?? '';
  }
}
