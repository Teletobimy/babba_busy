/// 반복 유형
enum RecurrenceType {
  none,    // 반복 안 함
  daily,   // 매일
  weekly,  // 매주
  monthly, // 매월
  yearly,  // 매년 (기념일)
}

/// RecurrenceType 확장 메서드
extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.none:
        return '반복 안 함';
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
    }
  }

  String get shortName {
    switch (this) {
      case RecurrenceType.none:
        return '';
      case RecurrenceType.daily:
        return '매일';
      case RecurrenceType.weekly:
        return '매주';
      case RecurrenceType.monthly:
        return '매월';
      case RecurrenceType.yearly:
        return '매년';
    }
  }
}

/// 요일 상수
class Weekdays {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;

  static const List<int> weekdays = [monday, tuesday, wednesday, thursday, friday];
  static const List<int> weekend = [saturday, sunday];
  static const List<int> all = [monday, tuesday, wednesday, thursday, friday, saturday, sunday];

  static String getName(int day) {
    switch (day) {
      case monday:
        return '월';
      case tuesday:
        return '화';
      case wednesday:
        return '수';
      case thursday:
        return '목';
      case friday:
        return '금';
      case saturday:
        return '토';
      case sunday:
        return '일';
      default:
        return '';
    }
  }

  static String getFullName(int day) {
    switch (day) {
      case monday:
        return '월요일';
      case tuesday:
        return '화요일';
      case wednesday:
        return '수요일';
      case thursday:
        return '목요일';
      case friday:
        return '금요일';
      case saturday:
        return '토요일';
      case sunday:
        return '일요일';
      default:
        return '';
    }
  }
}
