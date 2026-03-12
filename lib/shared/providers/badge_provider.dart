import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'smart_provider.dart';
import 'streak_provider.dart';

/// 뱃지 정의
class Badge {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final bool earned;

  const Badge({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    this.earned = false,
  });

  Badge copyWith({bool? earned}) => Badge(
    id: id, title: title, emoji: emoji,
    description: description,
    earned: earned ?? this.earned,
  );
}

/// 칭호 정의
class UserTitle {
  final String title;
  final int requiredCompletions;

  const UserTitle(this.title, this.requiredCompletions);
}

const _titles = [
  UserTitle('시작하는 사람', 0),
  UserTitle('실천가', 10),
  UserTitle('꾸준한 일꾼', 30),
  UserTitle('할일 마스터', 50),
  UserTitle('생산성 달인', 100),
  UserTitle('전설의 실행자', 200),
  UserTitle('완벽주의자', 500),
];

const _badgeDefinitions = [
  Badge(id: 'first_todo', title: '첫 걸음', emoji: '🎯', description: '첫 할일 완료'),
  Badge(id: 'streak_3', title: '3일 연속', emoji: '🔥', description: '3일 연속 달성'),
  Badge(id: 'streak_7', title: '일주일 파이터', emoji: '💪', description: '7일 연속 달성'),
  Badge(id: 'streak_30', title: '한 달 영웅', emoji: '🏆', description: '30일 연속 달성'),
  Badge(id: 'complete_10', title: '10개 클리어', emoji: '⭐', description: '총 10개 할일 완료'),
  Badge(id: 'complete_50', title: '50개 클리어', emoji: '🌟', description: '총 50개 할일 완료'),
  Badge(id: 'complete_100', title: '백전백승', emoji: '💎', description: '총 100개 할일 완료'),
  Badge(id: 'early_bird', title: '얼리버드', emoji: '🐦', description: '오전 7시 이전 할일 완료'),
  Badge(id: 'night_owl', title: '올빼미', emoji: '🦉', description: '자정 이후 할일 완료'),
];

/// 사용자의 뱃지 목록
final badgeListProvider = Provider<List<Badge>>((ref) {
  final todos = ref.watch(smartTodosProvider);
  final streak = ref.watch(streakProvider);
  final completedCount = todos.where((t) => t.isCompleted).length;

  return _badgeDefinitions.map((badge) {
    bool earned = false;
    switch (badge.id) {
      case 'first_todo':
        earned = completedCount >= 1;
        break;
      case 'streak_3':
        earned = streak >= 3;
        break;
      case 'streak_7':
        earned = streak >= 7;
        break;
      case 'streak_30':
        earned = streak >= 30;
        break;
      case 'complete_10':
        earned = completedCount >= 10;
        break;
      case 'complete_50':
        earned = completedCount >= 50;
        break;
      case 'complete_100':
        earned = completedCount >= 100;
        break;
      case 'early_bird':
        earned = todos.any((t) =>
          t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.hour < 7
        );
        break;
      case 'night_owl':
        earned = todos.any((t) =>
          t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.hour >= 0 &&
          t.completedAt!.hour < 4
        );
        break;
    }
    return badge.copyWith(earned: earned);
  }).toList();
});

/// 현재 칭호
final currentTitleProvider = Provider<String>((ref) {
  final todos = ref.watch(smartTodosProvider);
  final completedCount = todos.where((t) => t.isCompleted).length;

  String title = _titles.first.title;
  for (final t in _titles) {
    if (completedCount >= t.requiredCompletions) {
      title = t.title;
    }
  }
  return title;
});

/// 획득한 뱃지 수
final earnedBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(badgeListProvider).where((b) => b.earned).length;
});
