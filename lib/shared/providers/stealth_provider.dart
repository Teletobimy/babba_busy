import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 스텔스 모드 (private 할일 숨기기)
final stealthModeProvider = StateProvider<bool>((ref) => false);
