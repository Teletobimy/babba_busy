import 'package:cloud_firestore/cloud_firestore.dart';

/// 공휴일 모델
class Holiday {
  final String id;
  final String name; // 공휴일 이름
  final DateTime date;
  final bool isLunar; // 음력 여부 (설날, 추석 등)
  final bool isCustom; // 사용자 정의 공휴일 여부
  final String? familyId; // 그룹별 커스텀 공휴일인 경우

  Holiday({
    required this.id,
    required this.name,
    required this.date,
    this.isLunar = false,
    this.isCustom = false,
    this.familyId,
  });

  factory Holiday.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Holiday(
      id: doc.id,
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLunar: data['isLunar'] ?? false,
      isCustom: data['isCustom'] ?? false,
      familyId: data['familyId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
      'isLunar': isLunar,
      'isCustom': isCustom,
      'familyId': familyId,
    };
  }

  Holiday copyWith({
    String? id,
    String? name,
    DateTime? date,
    bool? isLunar,
    bool? isCustom,
    String? familyId,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      isLunar: isLunar ?? this.isLunar,
      isCustom: isCustom ?? this.isCustom,
      familyId: familyId ?? this.familyId,
    );
  }

  /// 날짜만 비교 (시간 무시)
  bool isSameDate(DateTime other) {
    return date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Holiday && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 한국 공휴일 데이터 (2024-2026)
class KoreanHolidays {
  /// 특정 연도의 공휴일 목록 반환
  static List<Holiday> getHolidaysForYear(int year) {
    final holidays = <Holiday>[];

    // 고정 공휴일
    holidays.addAll(_fixedHolidays(year));

    // 음력 공휴일 (설날, 추석) - 연도별 양력 변환값
    holidays.addAll(_lunarHolidays(year));

    return holidays;
  }

  /// 고정 공휴일 (양력)
  static List<Holiday> _fixedHolidays(int year) {
    return [
      Holiday(
        id: 'newyear_$year',
        name: '신정',
        date: DateTime(year, 1, 1),
      ),
      Holiday(
        id: 'independence_$year',
        name: '삼일절',
        date: DateTime(year, 3, 1),
      ),
      Holiday(
        id: 'children_$year',
        name: '어린이날',
        date: DateTime(year, 5, 5),
      ),
      Holiday(
        id: 'memorial_$year',
        name: '현충일',
        date: DateTime(year, 6, 6),
      ),
      Holiday(
        id: 'liberation_$year',
        name: '광복절',
        date: DateTime(year, 8, 15),
      ),
      Holiday(
        id: 'foundation_$year',
        name: '개천절',
        date: DateTime(year, 10, 3),
      ),
      Holiday(
        id: 'hangul_$year',
        name: '한글날',
        date: DateTime(year, 10, 9),
      ),
      Holiday(
        id: 'christmas_$year',
        name: '크리스마스',
        date: DateTime(year, 12, 25),
      ),
    ];
  }

  /// 음력 공휴일 (설날, 추석) - 연도별 양력 날짜
  static List<Holiday> _lunarHolidays(int year) {
    // 음력 -> 양력 변환값 (2024-2026)
    final lunarDates = {
      2024: {
        'seollal': [DateTime(2024, 2, 9), DateTime(2024, 2, 10), DateTime(2024, 2, 11), DateTime(2024, 2, 12)],
        'chuseok': [DateTime(2024, 9, 16), DateTime(2024, 9, 17), DateTime(2024, 9, 18)],
        'buddha': DateTime(2024, 5, 15),
      },
      2025: {
        'seollal': [DateTime(2025, 1, 28), DateTime(2025, 1, 29), DateTime(2025, 1, 30)],
        'chuseok': [DateTime(2025, 10, 5), DateTime(2025, 10, 6), DateTime(2025, 10, 7)],
        'buddha': DateTime(2025, 5, 5),
      },
      2026: {
        'seollal': [DateTime(2026, 2, 16), DateTime(2026, 2, 17), DateTime(2026, 2, 18)],
        'chuseok': [DateTime(2026, 9, 24), DateTime(2026, 9, 25), DateTime(2026, 9, 26)],
        'buddha': DateTime(2026, 5, 24),
      },
    };

    final yearData = lunarDates[year];
    if (yearData == null) return [];

    final holidays = <Holiday>[];

    // 설날 연휴
    final seollalDates = yearData['seollal'] as List<DateTime>?;
    if (seollalDates != null) {
      for (int i = 0; i < seollalDates.length; i++) {
        final suffix = i == 0 ? ' 전날' : (i == 1 ? '' : (i == 2 ? ' 다음날' : ' 대체휴일'));
        holidays.add(Holiday(
          id: 'seollal_${year}_$i',
          name: '설날$suffix',
          date: seollalDates[i],
          isLunar: true,
        ));
      }
    }

    // 추석 연휴
    final chuseokDates = yearData['chuseok'] as List<DateTime>?;
    if (chuseokDates != null) {
      for (int i = 0; i < chuseokDates.length; i++) {
        final suffix = i == 0 ? ' 전날' : (i == 1 ? '' : ' 다음날');
        holidays.add(Holiday(
          id: 'chuseok_${year}_$i',
          name: '추석$suffix',
          date: chuseokDates[i],
          isLunar: true,
        ));
      }
    }

    // 부처님 오신 날
    final buddhaDate = yearData['buddha'] as DateTime?;
    if (buddhaDate != null) {
      holidays.add(Holiday(
        id: 'buddha_$year',
        name: '부처님 오신 날',
        date: buddhaDate,
        isLunar: true,
      ));
    }

    return holidays;
  }

  /// 특정 날짜가 공휴일인지 확인
  static Holiday? getHolidayForDate(DateTime date, {String? familyId}) {
    final holidays = getHolidaysForYear(date.year);
    for (final holiday in holidays) {
      if (holiday.isSameDate(date)) {
        return holiday;
      }
    }
    return null;
  }

  /// 특정 월의 공휴일 목록
  static List<Holiday> getHolidaysForMonth(int year, int month) {
    return getHolidaysForYear(year)
        .where((h) => h.date.month == month)
        .toList();
  }
}
