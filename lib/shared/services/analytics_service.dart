import 'package:flutter/foundation.dart';

/// 앱 분석 서비스 (Firebase Analytics 연동 준비)
/// firebase_analytics 패키지 추가 후 실제 구현으로 교체 가능
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  /// 화면 전환 로깅
  void logScreenView(String screenName) {
    debugPrint('[Analytics] screen_view: $screenName');
  }

  /// 할일 완료 이벤트
  void logTodoCompleted({required String todoId, bool wasUndo = false}) {
    debugPrint('[Analytics] todo_completed: $todoId (undo: $wasUndo)');
  }

  /// 할일 생성 이벤트
  void logTodoCreated({required String eventType}) {
    debugPrint('[Analytics] todo_created: type=$eventType');
  }

  /// 그룹 관련 이벤트
  void logGroupAction(String action) {
    debugPrint('[Analytics] group_action: $action');
  }

  /// 도구 사용 이벤트
  void logToolUsed(String toolName) {
    debugPrint('[Analytics] tool_used: $toolName');
  }

  /// 커스텀 이벤트
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    debugPrint('[Analytics] $name: $parameters');
  }
}
