import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/providers/event_provider.dart';
import '../../shared/providers/auth_provider.dart';

/// Gemini AI 서비스 Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref);
});

/// AI 요약 Provider
final aiSummaryProvider = FutureProvider<String>((ref) async {
  final geminiService = ref.read(geminiServiceProvider);
  final todos = ref.watch(todosProvider).value ?? [];
  final events = ref.watch(eventsProvider).value ?? [];
  final memberName = ref.watch(currentMemberProvider).value?.name ?? '사용자';

  return geminiService.generateDailySummary(
    memberName: memberName,
    todos: todos,
    upcomingEventsCount: events.length,
  );
});

/// Gemini AI 서비스
class GeminiService {
  final Ref _ref;
  GenerativeModel? _model;

  // API 키는 환경변수나 Firebase Remote Config에서 가져와야 함
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';

  GeminiService(this._ref);

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-pro',
      apiKey: _apiKey,
    );
    return _model!;
  }

  /// 일간 요약 생성
  Future<String> generateDailySummary({
    required String memberName,
    required List<TodoItem> todos,
    required int upcomingEventsCount,
  }) async {
    // API 키가 없으면 기본 메시지 반환
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      return _generateLocalSummary(memberName, todos, upcomingEventsCount);
    }

    try {
      final pendingTodos = todos.where((t) => !t.isCompleted).toList();
      final completedTodos = todos.where((t) => t.isCompleted).toList();
      final todayTodos = pendingTodos.where((t) {
        if (t.dueDate == null) return false;
        final now = DateTime.now();
        return t.dueDate!.year == now.year &&
            t.dueDate!.month == now.month &&
            t.dueDate!.day == now.day;
      }).toList();

      final prompt = '''
당신은 가족 일정 관리 앱의 친근한 AI 비서입니다.
다음 정보를 바탕으로 $memberName님에게 오늘의 요약을 한두 문장으로 작성해주세요.
따뜻하고 격려하는 톤으로 작성하세요.

- 오늘 할일: ${todayTodos.length}개
- 전체 미완료 할일: ${pendingTodos.length}개
- 완료한 할일: ${completedTodos.length}개
- 다가오는 일정: $upcomingEventsCount개

간결하고 친근하게 작성해주세요.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? _generateLocalSummary(memberName, todos, upcomingEventsCount);
    } catch (e) {
      return _generateLocalSummary(memberName, todos, upcomingEventsCount);
    }
  }

  /// 주간 요약 생성
  Future<String> generateWeeklySummary({
    required String memberName,
    required List<TodoItem> todos,
    required int completedCount,
    required int totalCount,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      final rate = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;
      return '$memberName님, 이번 주 할일 완료율은 $rate%예요! ${rate >= 70 ? "잘하고 계세요! 🎉" : "조금만 더 힘내세요! 💪"}';
    }

    try {
      final rate = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

      final prompt = '''
당신은 가족 일정 관리 앱의 친근한 AI 비서입니다.
$memberName님의 이번 주 활동을 요약해주세요.

- 완료한 할일: $completedCount개
- 전체 할일: $totalCount개
- 완료율: $rate%

격려하는 톤으로 한두 문장으로 작성해주세요.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '이번 주도 수고하셨어요! 🌟';
    } catch (e) {
      return '이번 주도 수고하셨어요! 🌟';
    }
  }

  /// 로컬 요약 생성 (API 키 없을 때 사용)
  String _generateLocalSummary(String memberName, List<TodoItem> todos, int eventsCount) {
    final pendingCount = todos.where((t) => !t.isCompleted).length;
    final completedCount = todos.where((t) => t.isCompleted).length;

    if (pendingCount == 0 && completedCount == 0) {
      return '안녕하세요 $memberName님! 오늘의 할일을 추가해보세요 ✨';
    } else if (pendingCount == 0) {
      return '대단해요 $memberName님! 할일을 모두 완료했어요 🎉';
    } else if (pendingCount <= 3) {
      return '$memberName님, 오늘 할일 $pendingCount개만 남았어요. 조금만 더 힘내세요! 💪';
    } else {
      return '$memberName님, 오늘 할일이 $pendingCount개 있어요. 중요한 것부터 하나씩 해결해봐요! 📝';
    }
  }

  /// 할일 추천 생성
  Future<List<String>> suggestTodos({
    required String familyName,
    required List<TodoItem> recentTodos,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      return ['장보기', '청소하기', '운동하기'];
    }

    try {
      final recentTitles = recentTodos.take(5).map((t) => t.title).join(', ');

      final prompt = '''
가족 일정 관리 앱입니다. $familyName 가족에게 추천할 할일 3개를 제안해주세요.
최근 등록된 할일: $recentTitles

짧은 할일 제목만 3개, 줄바꿈으로 구분해서 작성해주세요.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      return text.split('\n').where((s) => s.trim().isNotEmpty).take(3).toList();
    } catch (e) {
      return ['장보기', '청소하기', '운동하기'];
    }
  }
}
