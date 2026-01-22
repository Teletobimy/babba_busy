/// 날짜 정규화 유틸리티
///
/// 날짜 비교 시 timezone과 시간 정보를 제거하고
/// 년/월/일만 사용하는 정규화된 DateTime을 반환합니다.
DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
