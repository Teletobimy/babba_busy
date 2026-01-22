import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 캘린더에서 완료된 항목 표시 여부
final showCompletedInCalendarProvider = StateProvider<bool>((ref) => true);
