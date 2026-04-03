import 'package:flutter/foundation.dart';

class AnalyticsEventRecord {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;

  const AnalyticsEventRecord({
    required this.name,
    required this.timestamp,
    required this.parameters,
  });
}

/// 앱 분석 서비스 (Firebase Analytics 연동 준비)
/// firebase_analytics 패키지 추가 후 실제 구현으로 교체 가능
class AnalyticsService {
  static const int _maxRecentEvents = 40;
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final ValueNotifier<List<AnalyticsEventRecord>> _recentEvents =
      ValueNotifier<List<AnalyticsEventRecord>>(const []);

  ValueListenable<List<AnalyticsEventRecord>> get recentEventsListenable =>
      _recentEvents;

  List<AnalyticsEventRecord> get recentEvents => _recentEvents.value;

  /// 화면 전환 로깅
  void logScreenView(String screenName) {
    _recordEvent('screen_view', {'screen_name': screenName});
  }

  /// 할일 완료 이벤트
  void logTodoCompleted({required String todoId, bool wasUndo = false}) {
    _recordEvent('todo_completed', {'todo_id': todoId, 'was_undo': wasUndo});
  }

  /// 할일 생성 이벤트
  void logTodoCreated({required String eventType}) {
    _recordEvent('todo_created', {'event_type': eventType});
  }

  /// 그룹 관련 이벤트
  void logGroupAction(String action) {
    _recordEvent('group_action', {'action': action});
  }

  /// 도구 사용 이벤트
  void logToolUsed(String toolName) {
    _recordEvent('tool_used', {'tool_name': toolName});
  }

  /// 커스텀 이벤트
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    _recordEvent(name, parameters ?? const {});
  }

  void clearRecentEvents() {
    _recentEvents.value = const [];
  }

  void _recordEvent(String name, Map<String, dynamic> parameters) {
    debugPrint('[Analytics] $name: $parameters');
    final nextEvents = List<AnalyticsEventRecord>.from(_recentEvents.value)
      ..add(
        AnalyticsEventRecord(
          name: name,
          timestamp: DateTime.now(),
          parameters: Map<String, dynamic>.from(parameters),
        ),
      );
    if (nextEvents.length > _maxRecentEvents) {
      nextEvents.removeRange(0, nextEvents.length - _maxRecentEvents);
    }
    _recentEvents.value = List<AnalyticsEventRecord>.unmodifiable(nextEvents);
  }
}
