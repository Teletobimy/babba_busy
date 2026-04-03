import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BabbaAiCapability {
  homeSummary,
  familyChatSummary,
  memoSummary,
  todoActions,
  calendarActions,
  noteActions,
  reminderActions,
}

class BabbaAiFeatureFlags {
  static const String _aiApiUrl = String.fromEnvironment('AI_API_URL');
  static const bool _homeSummaryRemoteEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_HOME_SUMMARY',
    defaultValue: true,
  );
  static const bool _chatSummaryRemoteEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_CHAT_SUMMARY',
    defaultValue: true,
  );
  static const bool _memoSummaryRemoteEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_MEMO_SUMMARY',
    defaultValue: true,
  );
  static const bool _todoActionsEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_TODO_ACTIONS',
    defaultValue: true,
  );
  static const bool _calendarActionsEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_CALENDAR_ACTIONS',
    defaultValue: true,
  );
  static const bool _noteActionsEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_NOTE_ACTIONS',
    defaultValue: true,
  );
  static const bool _reminderActionsEnabled = bool.fromEnvironment(
    'BABBA_USE_SUBAGENT_REMINDER_ACTIONS',
    defaultValue: true,
  );

  const BabbaAiFeatureFlags();

  bool get hasRemoteAiApi => _aiApiUrl.trim().isNotEmpty;

  bool get homeSummaryRemoteEnabled => _homeSummaryRemoteEnabled;
  bool get chatSummaryRemoteEnabled => _chatSummaryRemoteEnabled;
  bool get memoSummaryRemoteEnabled => _memoSummaryRemoteEnabled;
  bool get todoActionsRemoteEnabled => _todoActionsEnabled;
  bool get calendarActionsRemoteEnabled => _calendarActionsEnabled;
  bool get noteActionsRemoteEnabled => _noteActionsEnabled;
  bool get reminderActionsRemoteEnabled => _reminderActionsEnabled;

  bool get todoActionsAvailable => todoActionsRemoteEnabled && hasRemoteAiApi;
  bool get calendarActionsAvailable =>
      calendarActionsRemoteEnabled && hasRemoteAiApi;
  bool get noteActionsAvailable => noteActionsRemoteEnabled && hasRemoteAiApi;
  bool get reminderActionsAvailable =>
      reminderActionsRemoteEnabled && hasRemoteAiApi;

  bool get hasAnyHomeQuickActionAvailable =>
      todoActionsAvailable || reminderActionsAvailable;

  bool isEnabled(BabbaAiCapability capability) {
    return switch (capability) {
      BabbaAiCapability.homeSummary => homeSummaryRemoteEnabled,
      BabbaAiCapability.familyChatSummary => chatSummaryRemoteEnabled,
      BabbaAiCapability.memoSummary => memoSummaryRemoteEnabled,
      BabbaAiCapability.todoActions => todoActionsAvailable,
      BabbaAiCapability.calendarActions => calendarActionsAvailable,
      BabbaAiCapability.noteActions => noteActionsAvailable,
      BabbaAiCapability.reminderActions => reminderActionsAvailable,
    };
  }

  String? disabledReasonFor(BabbaAiCapability capability) {
    switch (capability) {
      case BabbaAiCapability.homeSummary:
        return homeSummaryRemoteEnabled
            ? null
            : 'AI 홈 요약 import가 현재 배포에서 꺼져 있습니다.';
      case BabbaAiCapability.familyChatSummary:
        return chatSummaryRemoteEnabled
            ? null
            : 'AI 가족 채팅 요약이 현재 배포에서 꺼져 있습니다.';
      case BabbaAiCapability.memoSummary:
        return memoSummaryRemoteEnabled ? null : 'AI 메모 요약이 현재 배포에서 꺼져 있습니다.';
      case BabbaAiCapability.todoActions:
        if (!todoActionsRemoteEnabled) {
          return 'AI 개인 할 일 액션이 현재 배포에서 꺼져 있습니다.';
        }
        if (!hasRemoteAiApi) {
          return 'AI action backend가 아직 연결되지 않아 개인 할 일 액션을 사용할 수 없습니다.';
        }
        return null;
      case BabbaAiCapability.calendarActions:
        if (!calendarActionsRemoteEnabled) {
          return 'AI 개인 일정 액션이 현재 배포에서 꺼져 있습니다.';
        }
        if (!hasRemoteAiApi) {
          return 'AI action backend가 아직 연결되지 않아 개인 일정 액션을 사용할 수 없습니다.';
        }
        return null;
      case BabbaAiCapability.noteActions:
        if (!noteActionsRemoteEnabled) {
          return 'AI 개인 메모 액션이 현재 배포에서 꺼져 있습니다.';
        }
        if (!hasRemoteAiApi) {
          return 'AI action backend가 아직 연결되지 않아 개인 메모 액션을 사용할 수 없습니다.';
        }
        return null;
      case BabbaAiCapability.reminderActions:
        if (!reminderActionsRemoteEnabled) {
          return 'AI 개인 리마인더 액션이 현재 배포에서 꺼져 있습니다.';
        }
        if (!hasRemoteAiApi) {
          return 'AI action backend가 아직 연결되지 않아 개인 리마인더 액션을 사용할 수 없습니다.';
        }
        return null;
    }
  }

  String get homeQuickActionDisabledReason {
    final todoReason = disabledReasonFor(BabbaAiCapability.todoActions);
    if (todoReason != null) {
      return todoReason;
    }
    final reminderReason = disabledReasonFor(BabbaAiCapability.reminderActions);
    if (reminderReason != null) {
      return reminderReason;
    }
    return 'AI 빠른 액션을 현재 사용할 수 없습니다.';
  }
}

final babbaAiFeatureFlagsProvider = Provider<BabbaAiFeatureFlags>((ref) {
  return const BabbaAiFeatureFlags();
});
