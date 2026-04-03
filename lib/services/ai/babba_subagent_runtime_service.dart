import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/chat_message.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/providers/ai_feature_flag_provider.dart';
import '../../shared/services/ai_telemetry_service.dart';
import '../gemini/gemini_service.dart';
import 'ai_api_service.dart';

final babbaSubagentRuntimeServiceProvider =
    Provider<BabbaSubagentRuntimeService>((ref) {
      return BabbaSubagentRuntimeService(
        aiApiService: ref.read(aiApiServiceProvider),
        geminiService: ref.read(geminiServiceProvider),
        featureFlags: ref.read(babbaAiFeatureFlagsProvider),
        telemetry: ref.read(aiTelemetryServiceProvider),
      );
    });

/// BABBA가 소유하는 서브에이전트 런타임 진입점
class BabbaSubagentRuntimeService {
  final AiApiService _aiApiService;
  final GeminiService _geminiService;
  final BabbaAiFeatureFlags _featureFlags;
  final AiTelemetryService _telemetry;

  BabbaSubagentRuntimeService({
    required AiApiService aiApiService,
    required GeminiService geminiService,
    required BabbaAiFeatureFlags featureFlags,
    required AiTelemetryService telemetry,
  }) : _aiApiService = aiApiService,
       _geminiService = geminiService,
       _featureFlags = featureFlags,
       _telemetry = telemetry;

  Future<String> generateHomeSummary({
    required String? userId,
    required String userName,
    required String? selectedMemberId,
    required String? selectedMemberName,
    required int pendingTodos,
    required int completedToday,
    required int upcomingEvents,
    required List<TodoItem> fallbackTodos,
    String source = 'home_summary_card',
  }) async {
    final effectiveName = (selectedMemberName ?? userName).trim().isEmpty
        ? '사용자'
        : (selectedMemberName ?? userName).trim();

    if (_featureFlags.homeSummaryRemoteEnabled &&
        userId != null &&
        userId.isNotEmpty &&
        _aiApiService.hasConfiguredBaseUrl) {
      try {
        final result = await _aiApiService.generateHomeAgentSummary(
          userId: userId,
          userName: userName,
          selectedMemberId: selectedMemberId,
          selectedMemberName: selectedMemberName,
          pendingTodos: pendingTodos,
          completedToday: completedToday,
          upcomingEvents: upcomingEvents,
        );
        if (result.summary.trim().isNotEmpty) {
          _telemetry.logSummaryRendered(
            toolName: BabbaAiTools.homeSummary,
            source: source,
            capability: BabbaAiCapability.homeSummary,
            transport: 'subagent_remote',
            fallbackUsed: false,
            cached: result.cached,
            extra: {'selected_member_filtered': selectedMemberId != null},
          );
          return result.summary.trim();
        }
      } on AiApiException {
        // Cloud Run route가 아직 비활성화되었거나 실패한 경우 기존 Gemini 경로로 폴백.
      } catch (_) {
        // 홈 첫 진입을 막지 않도록 모든 원격 예외는 로컬 요약으로 전환한다.
      }
    }

    try {
      final summary = await _geminiService.generateDailySummary(
        memberName: effectiveName,
        todos: fallbackTodos,
        upcomingTodosCount: upcomingEvents,
      );
      _telemetry.logSummaryRendered(
        toolName: BabbaAiTools.homeSummary,
        source: source,
        capability: BabbaAiCapability.homeSummary,
        transport: 'local_gemini',
        fallbackUsed: true,
        cached: false,
        extra: {'selected_member_filtered': selectedMemberId != null},
      );
      return summary;
    } catch (error) {
      _telemetry.logSummaryFailed(
        toolName: BabbaAiTools.homeSummary,
        source: source,
        capability: BabbaAiCapability.homeSummary,
        transport: 'local_gemini',
        fallbackUsed: true,
        error: error,
      );
      rethrow;
    }
  }

  Future<FamilyChatSummaryResult> generateFamilyChatSummary({
    required String? userId,
    required String? familyId,
    required String? familyName,
    required List<ChatMessage> messages,
    String source = 'tools_family_chat',
  }) async {
    final effectiveFamilyName = (familyName ?? '').trim().isEmpty
        ? '가족 채팅'
        : familyName!.trim();

    if (_featureFlags.chatSummaryRemoteEnabled &&
        userId != null &&
        userId.isNotEmpty &&
        familyId != null &&
        familyId.isNotEmpty &&
        _aiApiService.hasConfiguredBaseUrl) {
      try {
        final result = await _aiApiService.generateFamilyChatSummary(
          userId: userId,
          familyId: familyId,
          familyName: effectiveFamilyName,
          limitMessages: 40,
        );
        _telemetry.logSummaryRendered(
          toolName: BabbaAiTools.familyChatSummary,
          source: source,
          capability: BabbaAiCapability.familyChatSummary,
          transport: 'subagent_remote',
          fallbackUsed: false,
          cached: result.cached,
          extra: {
            'message_count': result.messageCount,
            'participant_count': result.participantCount,
          },
        );
        return result;
      } on AiApiException {
        // 원격 요약 실패 시 채팅 화면 동작을 막지 않고 로컬 read-only 요약으로 내린다.
      } catch (_) {
        // 비정상 응답도 동일하게 로컬 요약으로 처리한다.
      }
    }

    final localSummary = _buildLocalFamilyChatSummary(
      familyName: effectiveFamilyName,
      messages: messages,
    );
    _telemetry.logSummaryRendered(
      toolName: BabbaAiTools.familyChatSummary,
      source: source,
      capability: BabbaAiCapability.familyChatSummary,
      transport: 'local_summary',
      fallbackUsed: true,
      cached: false,
      extra: {
        'message_count': localSummary.messageCount,
        'participant_count': localSummary.participantCount,
      },
    );
    return localSummary;
  }

  FamilyChatSummaryResult _buildLocalFamilyChatSummary({
    required String familyName,
    required List<ChatMessage> messages,
  }) {
    if (messages.isEmpty) {
      return FamilyChatSummaryResult(
        familyId: '',
        familyName: familyName,
        summary: '아직 요약할 대화가 없어요.',
      );
    }

    final recentMessages = messages.length > 40
        ? messages.sublist(messages.length - 40)
        : messages;
    final participants = <String>[];
    for (final message in recentMessages) {
      if (message.senderId == 'system') continue;
      if (!participants.contains(message.senderName)) {
        participants.add(message.senderName);
      }
    }

    final lastMessage = recentMessages.last;
    final lastLabel = _normalizeLocalChatMessage(lastMessage);

    return FamilyChatSummaryResult(
      familyId: lastMessage.familyId,
      familyName: familyName,
      summary:
          '$familyName 최근 대화 ${recentMessages.length}개를 확인했어요. ${participants.length}명이 참여했고, '
          '가장 최근 메시지는 ${lastMessage.senderName}님이 남겼어요.',
      highlights: [
        '최근 메시지 ${recentMessages.length}개를 기준으로 정리했어요.',
        '대화 참여 인원은 ${participants.length}명이에요.',
        '가장 최근 메시지: ${lastMessage.senderName}님 - ${_truncate(lastLabel, 36)}',
      ],
      messageCount: recentMessages.length,
      participantCount: participants.length,
      latestMessageAt: lastMessage.createdAt,
      cached: false,
    );
  }

  String _normalizeLocalChatMessage(ChatMessage message) {
    final content = message.content.trim();
    switch (message.type) {
      case MessageType.image:
        if (content.isNotEmpty && content != '사진') {
          return '[사진] $content';
        }
        return '[사진 공유]';
      case MessageType.file:
        if ((message.attachmentName ?? '').trim().isNotEmpty) {
          return '[파일] ${message.attachmentName!.trim()}';
        }
        return '[파일 공유]';
      case MessageType.system:
        return content.isEmpty ? '[시스템]' : '[시스템] $content';
      case MessageType.text:
        return content.isEmpty ? '[내용 없음]' : content;
    }
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 1)}...';
  }

  Future<MemoAnalysisResult> generateMemoSummary({
    required String? userId,
    required String content,
    String? memoTitle,
    String? categoryName,
    String source = 'memo_detail_summary',
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.length < 20) {
      _telemetry.logSummaryFailed(
        toolName: BabbaAiTools.memoSummary,
        source: source,
        capability: BabbaAiCapability.memoSummary,
        transport: 'validation',
        fallbackUsed: false,
        error: AiApiException('내용이 너무 짧습니다 (최소 20자)'),
      );
      throw AiApiException('내용이 너무 짧습니다 (최소 20자)');
    }

    if (_featureFlags.memoSummaryRemoteEnabled &&
        userId != null &&
        userId.isNotEmpty &&
        _aiApiService.hasConfiguredBaseUrl) {
      try {
        final result = await _aiApiService.generateMemoAgentSummary(
          userId: userId,
          content: normalizedContent,
          memoTitle: memoTitle,
          categoryName: categoryName,
        );
        if (result.analysis.trim().isNotEmpty ||
            result.summary.trim().isNotEmpty) {
          _telemetry.logSummaryRendered(
            toolName: BabbaAiTools.memoSummary,
            source: source,
            capability: BabbaAiCapability.memoSummary,
            transport: 'subagent_remote',
            fallbackUsed: false,
            cached: false,
          );
          return result;
        }
      } on AiApiException {
        // 새 agent route가 준비되지 않았거나 실패하면 기존 memo analyze 경로로 내린다.
      } catch (_) {
        // 메모 편집 흐름은 유지하고 기존 경로로 폴백한다.
      }
    }

    try {
      final legacyResult = await _aiApiService.analyzeMemo(
        userId: userId ?? '',
        content: normalizedContent,
        categoryName: categoryName,
      );
      _telemetry.logSummaryRendered(
        toolName: BabbaAiTools.memoSummary,
        source: source,
        capability: BabbaAiCapability.memoSummary,
        transport: 'legacy_api',
        fallbackUsed: true,
        cached: false,
      );
      return legacyResult;
    } on AiApiException {
      // Cloud Run 전체가 실패한 경우 로컬 Gemini로 마지막 폴백.
    } catch (_) {
      // fall through to local summary
    }

    final localAnalysis = await _geminiService.analyzeMemo(
      content: normalizedContent,
      categoryName: categoryName,
    );
    final trimmedLocalAnalysis = localAnalysis.trim();
    if (trimmedLocalAnalysis.isEmpty) {
      _telemetry.logSummaryFailed(
        toolName: BabbaAiTools.memoSummary,
        source: source,
        capability: BabbaAiCapability.memoSummary,
        transport: 'local_gemini',
        fallbackUsed: true,
        error: AiApiException('AI 요약을 수행할 수 없습니다.'),
      );
      throw AiApiException('AI 요약을 수행할 수 없습니다.');
    }

    final result = MemoAnalysisResult(
      analysis: trimmedLocalAnalysis,
      summary: _firstNonEmptyLine(trimmedLocalAnalysis),
    );
    _telemetry.logSummaryRendered(
      toolName: BabbaAiTools.memoSummary,
      source: source,
      capability: BabbaAiCapability.memoSummary,
      transport: 'local_gemini',
      fallbackUsed: true,
      cached: false,
    );
    return result;
  }

  String _firstNonEmptyLine(String text) {
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isNotEmpty) {
        return _truncate(line, 180);
      }
    }
    return _truncate(text.trim(), 180);
  }

  Future<AgentNoteCreatePreviewResult> previewPersonalNoteCreate({
    required String? userId,
    required String prompt,
    String? source,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('메모 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.noteActionsRemoteEnabled) {
      throw AiApiException('AI 메모 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalNoteCreateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
    );
  }

  Future<AgentNoteCreateDecisionResult> submitPersonalNoteCreateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.noteActionsRemoteEnabled) {
      throw AiApiException('AI 메모 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalNoteCreateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentNoteUpdatePreviewResult> previewPersonalNoteUpdate({
    required String? userId,
    required String prompt,
    String? source,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('수정할 메모 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.noteActionsRemoteEnabled) {
      throw AiApiException('AI 메모 수정 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalNoteUpdateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
    );
  }

  Future<AgentNoteUpdateDecisionResult> submitPersonalNoteUpdateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.noteActionsRemoteEnabled) {
      throw AiApiException('AI 메모 수정 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalNoteUpdateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentReminderCreatePreviewResult> previewPersonalReminderCreate({
    required String? userId,
    required String prompt,
    String? source,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('리마인더 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.reminderActionsRemoteEnabled) {
      throw AiApiException('AI 리마인더 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalReminderCreateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
    );
  }

  Future<AgentReminderCreateDecisionResult>
  submitPersonalReminderCreateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.reminderActionsRemoteEnabled) {
      throw AiApiException('AI 리마인더 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalReminderCreateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentTodoCreatePreviewResult> previewPersonalTodoCreate({
    required String? userId,
    required String prompt,
    String? source,
    String? currentGroupId,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('할 일 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.todoActionsRemoteEnabled) {
      throw AiApiException('AI 할 일 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalTodoCreateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
      currentGroupId: currentGroupId,
    );
  }

  Future<AgentTodoCreateDecisionResult> submitPersonalTodoCreateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.todoActionsRemoteEnabled) {
      throw AiApiException('AI 할 일 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalTodoCreateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentTodoCompletePreviewResult> previewPersonalTodoComplete({
    required String? userId,
    required String prompt,
    String? source,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('완료할 할 일을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.todoActionsRemoteEnabled) {
      throw AiApiException('AI 할 일 완료 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalTodoCompleteAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
    );
  }

  Future<AgentTodoCompleteDecisionResult> submitPersonalTodoCompleteDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.todoActionsRemoteEnabled) {
      throw AiApiException('AI 할 일 완료 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalTodoCompleteDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentCalendarCreatePreviewResult> previewPersonalCalendarCreate({
    required String? userId,
    required String prompt,
    String? source,
    String? currentGroupId,
    DateTime? selectedDate,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('일정 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.calendarActionsRemoteEnabled) {
      throw AiApiException('AI 일정 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalCalendarCreateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
      currentGroupId: currentGroupId,
      selectedDate: selectedDate,
    );
  }

  Future<AgentCalendarCreateDecisionResult>
  submitPersonalCalendarCreateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.calendarActionsRemoteEnabled) {
      throw AiApiException('AI 일정 생성 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalCalendarCreateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }

  Future<AgentCalendarUpdatePreviewResult> previewPersonalCalendarUpdate({
    required String? userId,
    required String prompt,
    String? source,
    DateTime? selectedDate,
  }) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.length < 2) {
      throw AiApiException('수정할 일정 요청을 더 구체적으로 입력해주세요.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.calendarActionsRemoteEnabled) {
      throw AiApiException('AI 일정 수정 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.previewPersonalCalendarUpdateAction(
      userId: userId,
      prompt: normalizedPrompt,
      source: source,
      selectedDate: selectedDate,
    );
  }

  Future<AgentCalendarUpdateDecisionResult>
  submitPersonalCalendarUpdateDecision({
    required String? userId,
    required String requestId,
    required bool approved,
  }) async {
    final normalizedRequestId = requestId.trim();
    if (normalizedRequestId.isEmpty) {
      throw AiApiException('유효한 요청 ID가 없습니다.');
    }
    if (userId == null || userId.isEmpty) {
      throw AiApiException('로그인이 필요합니다.');
    }
    if (!_featureFlags.calendarActionsRemoteEnabled) {
      throw AiApiException('AI 일정 수정 기능이 비활성화되어 있습니다.');
    }
    if (!_aiApiService.hasConfiguredBaseUrl) {
      throw AiApiException('AI API URL이 설정되지 않았습니다.');
    }

    return _aiApiService.submitPersonalCalendarUpdateDecision(
      userId: userId,
      requestId: normalizedRequestId,
      approved: approved,
    );
  }
}
