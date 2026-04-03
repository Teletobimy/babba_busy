import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_feature_flag_provider.dart';
import 'analytics_service.dart';

abstract final class BabbaAiTools {
  static const String homeQuickActions = 'home_quick_actions';
  static const String homeSummary = 'home_summary';
  static const String familyChatSummary = 'family_chat_summary';
  static const String memoSummary = 'memo_summary';
  static const String calendarActions = 'calendar_actions';
  static const String noteActions = 'note_actions';
  static const String todoCreate = 'todo_create';
  static const String todoComplete = 'todo_complete';
  static const String calendarCreate = 'calendar_create';
  static const String calendarUpdate = 'calendar_update';
  static const String noteCreate = 'note_create';
  static const String noteUpdate = 'note_update';
  static const String reminderCreate = 'reminder_create';
}

final aiTelemetryServiceProvider = Provider<AiTelemetryService>((ref) {
  return AiTelemetryService(
    analytics: AnalyticsService(),
    flags: ref.read(babbaAiFeatureFlagsProvider),
  );
});

class AiTelemetryService {
  final AnalyticsService _analytics;
  final BabbaAiFeatureFlags _flags;

  const AiTelemetryService({
    required AnalyticsService analytics,
    required BabbaAiFeatureFlags flags,
  }) : _analytics = analytics,
       _flags = flags;

  void logEntryTapped({
    required String toolName,
    required String source,
    BabbaAiCapability? capability,
    required bool enabled,
    String? disabledReason,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_entry_tapped',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'enabled': enabled,
        if (disabledReason != null && disabledReason.trim().isNotEmpty)
          'disabled_reason': disabledReason.trim(),
        ...?extra,
      },
    );
  }

  void logSummaryRendered({
    required String toolName,
    required String source,
    required String transport,
    required bool fallbackUsed,
    BabbaAiCapability? capability,
    bool? cached,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_summary_rendered',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'transport': transport,
        'fallback_used': fallbackUsed,
        if (cached != null) 'cached': cached,
        ...?extra,
      },
    );
  }

  void logSummaryFailed({
    required String toolName,
    required String source,
    required Object error,
    required String transport,
    required bool fallbackUsed,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_summary_failed',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'transport': transport,
        'fallback_used': fallbackUsed,
        'error_type': error.runtimeType.toString(),
        'error_message': _truncate(error.toString()),
        ...?extra,
      },
    );
  }

  void logPreviewRequested({
    required String toolName,
    required String source,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_preview_requested',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: extra,
    );
  }

  void logPreviewBlocked({
    required String toolName,
    required String source,
    required String reason,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_preview_blocked',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {'reason': _truncate(reason), ...?extra},
    );
  }

  void logPreviewRendered({
    required String toolName,
    required String source,
    String? requestId,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_preview_rendered',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        if (requestId != null && requestId.trim().isNotEmpty)
          'request_id': requestId.trim(),
        ...?extra,
      },
    );
  }

  void logPreviewFailed({
    required String toolName,
    required String source,
    required Object error,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_preview_failed',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'error_type': error.runtimeType.toString(),
        'error_message': _truncate(error.toString()),
        ...?extra,
      },
    );
  }

  void logConsentShown({
    required String toolName,
    required String source,
    String? requestId,
    BabbaAiCapability? capability,
  }) {
    _log(
      'ai_consent_shown',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        if (requestId != null && requestId.trim().isNotEmpty)
          'request_id': requestId.trim(),
      },
    );
  }

  void logConsentOutcome({
    required String toolName,
    required String source,
    required String outcome,
    String? requestId,
    BabbaAiCapability? capability,
  }) {
    _log(
      'ai_consent_outcome',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'outcome': outcome,
        if (requestId != null && requestId.trim().isNotEmpty)
          'request_id': requestId.trim(),
      },
    );
  }

  void logActionResult({
    required String toolName,
    required String source,
    required String outcome,
    String? requestId,
    String? auditId,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    _log(
      'ai_action_result',
      toolName: toolName,
      source: source,
      capability: capability,
      extra: {
        'outcome': outcome,
        if (requestId != null && requestId.trim().isNotEmpty)
          'request_id': requestId.trim(),
        if (auditId != null && auditId.trim().isNotEmpty)
          'audit_id': auditId.trim(),
        ...?extra,
      },
    );
  }

  void _log(
    String eventName, {
    required String toolName,
    required String source,
    BabbaAiCapability? capability,
    Map<String, Object?>? extra,
  }) {
    final parameters = <String, dynamic>{
      'tool_requested': toolName,
      'trigger_source': source,
      'remote_ai_api_connected': _flags.hasRemoteAiApi,
      if (capability != null) 'capability': capability.name,
      if (capability != null) 'feature_enabled': _flags.isEnabled(capability),
      ..._normalize(extra),
    };
    _analytics.logEvent(eventName, parameters: parameters);
  }

  Map<String, dynamic> _normalize(Map<String, Object?>? values) {
    if (values == null || values.isEmpty) {
      return const {};
    }

    final normalized = <String, dynamic>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        normalized[entry.key] = _truncate(trimmed);
        continue;
      }
      normalized[entry.key] = value;
    }
    return normalized;
  }

  String _truncate(String value, {int maxLength = 180}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1)}...';
  }
}
