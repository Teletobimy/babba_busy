import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/holiday.dart';
import 'auth_provider.dart';
import 'group_provider.dart';

/// 선택된 연도
final selectedHolidayYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// 특정 연도의 한국 공휴일 목록
final koreanHolidaysProvider = Provider.family<List<Holiday>, int>((ref, year) {
  return KoreanHolidays.getHolidaysForYear(year);
});

/// 현재 선택된 연도의 공휴일 목록
final currentYearHolidaysProvider = Provider<List<Holiday>>((ref) {
  final year = ref.watch(selectedHolidayYearProvider);
  return ref.watch(koreanHolidaysProvider(year));
});

/// 그룹 커스텀 공휴일 (Firestore)
final customHolidaysProvider = StreamProvider<List<Holiday>>((ref) {
  final membership = ref.watch(currentMembershipProvider);
  final firestore = ref.watch(firestoreProvider);
  if (membership == null || firestore == null) return Stream.value([]);

  return firestore
      .collection('families')
      .doc(membership.groupId)
      .collection('custom_holidays')
      .orderBy('date')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Holiday.fromFirestore(doc)).toList());
});

/// 특정 연도의 전체 공휴일 (한국 공휴일 + 커스텀 공휴일)
final allHolidaysForYearProvider = Provider.family<List<Holiday>, int>((ref, year) {
  final korean = ref.watch(koreanHolidaysProvider(year));
  final custom = ref.watch(customHolidaysProvider).value ?? [];

  // 해당 연도의 커스텀 공휴일만 필터링
  final yearCustom = custom.where((h) => h.date.year == year).toList();

  return [...korean, ...yearCustom];
});

/// 특정 월의 공휴일 목록
final monthHolidaysProvider = Provider.family<List<Holiday>, ({int year, int month})>((ref, params) {
  final allHolidays = ref.watch(allHolidaysForYearProvider(params.year));
  return allHolidays.where((h) => h.date.month == params.month).toList();
});

/// 특정 날짜의 공휴일 확인
final holidayForDateProvider = Provider.family<Holiday?, DateTime>((ref, date) {
  final holidays = ref.watch(allHolidaysForYearProvider(date.year));
  for (final holiday in holidays) {
    if (holiday.isSameDate(date)) {
      return holiday;
    }
  }
  return null;
});

/// 특정 날짜가 공휴일인지 확인
final isHolidayProvider = Provider.family<bool, DateTime>((ref, date) {
  return ref.watch(holidayForDateProvider(date)) != null;
});

/// 공휴일 서비스 Provider
final holidayServiceProvider = Provider<HolidayService>((ref) {
  return HolidayService(ref);
});

/// 공휴일 서비스 (커스텀 공휴일 관리)
class HolidayService {
  final Ref _ref;

  HolidayService(this._ref);

  FirebaseFirestore? get _firestore => _ref.read(firestoreProvider);
  String? get _groupId => _ref.read(currentMembershipProvider)?.groupId;

  CollectionReference? get _customHolidaysCollection {
    if (_groupId == null || _firestore == null) return null;
    return _firestore!.collection('families').doc(_groupId).collection('custom_holidays');
  }

  /// 커스텀 공휴일 추가
  Future<String?> addCustomHoliday({
    required String name,
    required DateTime date,
  }) async {
    final collection = _customHolidaysCollection;
    if (collection == null) return null;

    final doc = await collection.add({
      'name': name,
      'date': Timestamp.fromDate(date),
      'isLunar': false,
      'isCustom': true,
      'familyId': _groupId,
    });

    return doc.id;
  }

  /// 커스텀 공휴일 수정
  Future<void> updateCustomHoliday(
    String holidayId, {
    String? name,
    DateTime? date,
  }) async {
    final collection = _customHolidaysCollection;
    if (collection == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (date != null) updates['date'] = Timestamp.fromDate(date);

    if (updates.isNotEmpty) {
      await collection.doc(holidayId).update(updates);
    }
  }

  /// 커스텀 공휴일 삭제
  Future<void> deleteCustomHoliday(String holidayId) async {
    final collection = _customHolidaysCollection;
    if (collection == null) return;
    await collection.doc(holidayId).delete();
  }

  /// 특정 날짜가 공휴일인지 확인 (반복 일정에서 사용)
  bool isHoliday(DateTime date) {
    final holidays = _ref.read(allHolidaysForYearProvider(date.year));
    return holidays.any((h) => h.isSameDate(date));
  }

  /// 특정 날짜의 공휴일 정보 반환
  Holiday? getHolidayForDate(DateTime date) {
    final holidays = _ref.read(allHolidaysForYearProvider(date.year));
    for (final holiday in holidays) {
      if (holiday.isSameDate(date)) {
        return holiday;
      }
    }
    return null;
  }
}
