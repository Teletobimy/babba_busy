import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/providers/todo_provider.dart';
import '../../shared/providers/event_provider.dart';
import '../../shared/providers/smart_provider.dart';

/// Gemini AI 서비스 Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref);
});

/// AI 요약 Provider
final aiSummaryProvider = FutureProvider<String>((ref) async {
  final geminiService = ref.read(geminiServiceProvider);
  final todos = ref.watch(todosProvider).value ?? [];
  final events = ref.watch(eventsProvider).value ?? [];
  final currentMember = ref.watch(smartCurrentMemberProvider);
  final memberName = currentMember?.name ?? '사용자';

  return geminiService.generateDailySummary(
    memberName: memberName,
    todos: todos,
    upcomingEventsCount: events.length,
  );
});

/// Gemini AI 서비스
class GeminiService {
  GenerativeModel? _model;

  // API 키: 빌드 시 --dart-define 또는 .env 파일에서 로드
  static String get _apiKey {
    // 1. 빌드 시 주입된 값 우선 (배포용)
    const buildTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (buildTimeKey.isNotEmpty) return buildTimeKey;

    // 2. .env 파일에서 로드 (개발용)
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  GeminiService(Ref _);

  /// API 키가 설정되어 있는지 확인
  bool get hasApiKey => _apiKey.isNotEmpty;

  GenerativeModel get model {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
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
    if (!hasApiKey) {
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
    if (!hasApiKey) {
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

  /// 메모 분석
  Future<String> analyzeMemo({
    required String content,
    String? categoryName,
  }) async {
    // API 키가 없거나 내용이 너무 짧으면 빈 문자열 반환
    if (!hasApiKey || content.length < 20) {
      return '';
    }

    try {
      final prompt = '''
당신은 개인 메모 분석 AI입니다.
다음 메모를 분석하여 핵심 인사이트를 2-3문장으로 요약해주세요.
따뜻하고 도움이 되는 톤으로 작성하세요.
${categoryName != null ? '카테고리: $categoryName' : ''}

메모 내용:
$content

응답 형식:
- 핵심 주제나 감정 파악
- 실행 가능한 조언이나 인사이트 (해당 시)
- 격려나 공감의 한마디
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 할일 추천 생성
  Future<List<String>> suggestTodos({
    required String familyName,
    required List<TodoItem> recentTodos,
  }) async {
    if (!hasApiKey) {
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
