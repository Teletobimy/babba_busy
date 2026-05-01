import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai/ai_api_service.dart';

/// User Brain 최근 suggestion 목록 — 홈 카드에서 watch.
final userBrainSuggestionsProvider =
    FutureProvider.autoDispose<UserBrainSuggestionListResult>((ref) async {
  final svc = ref.watch(aiApiServiceProvider);
  return svc.listUserBrainSuggestions(limit: 20);
});

/// 홈 화면 첫 진입 시 reflection 1회 실행 후 suggestions invalidate.
final userBrainInitialReflectProvider =
    FutureProvider.autoDispose<UserBrainReflectResult>((ref) async {
  final svc = ref.watch(aiApiServiceProvider);
  final result = await svc.runUserBrainReflect();
  // reflect 직후 suggestions 갱신
  ref.invalidate(userBrainSuggestionsProvider);
  return result;
});
