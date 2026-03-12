import 'dart:math';

/// 격려 메시지 생성기
class EncouragementMessages {
  static final _random = Random();

  static String getCompletionMessage({int streak = 0, bool isFirst = false}) {
    if (isFirst) return _firstMessages[_random.nextInt(_firstMessages.length)];
    if (streak >= 7) return _streakMessages[_random.nextInt(_streakMessages.length)].replaceAll('{n}', '$streak');
    if (streak >= 3) return _midStreakMessages[_random.nextInt(_midStreakMessages.length)].replaceAll('{n}', '$streak');
    return _generalMessages[_random.nextInt(_generalMessages.length)];
  }

  static String getLateNightMessage() {
    return _lateNightMessages[_random.nextInt(_lateNightMessages.length)];
  }

  static const _generalMessages = [
    '잘했어요!',
    '멋져요!',
    '하나 끝!',
    '좋은 진전이에요!',
    '해냈어요!',
    '훌륭해요!',
    '한 걸음 더!',
    '잘 하고 있어요!',
    '최고예요!',
    '파이팅!',
    '대단해요!',
    '완벽해요!',
    '이 조자도 대단한 거예요!',
    '하나씩 해결하고 있어요!',
    '오늘도 한 발짝 앞으로!',
  ];

  static const _firstMessages = [
    '오늘의 첫 완료! 좋은 시작이에요!',
    '첫 번째 할일 완료! 나머지도 해볼까요?',
    '시작이 반! 잘 하고 있어요!',
    '오늘의 시작을 열었어요!',
  ];

  static const _midStreakMessages = [
    '{n}일 연속 달성! 계속 이 기세!',
    '{n}일째 이어가고 있어요!',
    '벌써 {n}일째! 대단해요!',
  ];

  static const _streakMessages = [
    '{n}일 연속! 정말 대단해요!',
    '{n}일 연속 달성! 당신은 진짜 프로!',
    'WOW! {n}일 연속이라니!',
    '{n}일째! 꾸준함이 빛나요!',
  ];

  static const _lateNightMessages = [
    '밤늦게까지 고생하셨어요. 푹 쉬세요!',
    '이 시간에도! 내일은 좀 쉬어가요!',
    '밤 올빼미시군요! 잘 자요!',
  ];
}
