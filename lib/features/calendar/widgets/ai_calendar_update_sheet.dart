import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ai/ai_api_service.dart';
import '../../../services/ai/babba_subagent_runtime_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/ai_feature_flag_provider.dart';
import '../../../shared/services/ai_telemetry_service.dart';
import '../../../shared/utils/ai_personal_scope_guard.dart';
import '../../../shared/widgets/ai_action_consent_sheet.dart';

Future<AgentCalendarUpdateDecisionResult?> showAiCalendarUpdateSheet({
  required BuildContext context,
  required DateTime selectedDate,
  String initialPrompt = '',
}) {
  return showModalBottomSheet<AgentCalendarUpdateDecisionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AiCalendarUpdateSheet(
      selectedDate: selectedDate,
      initialPrompt: initialPrompt,
    ),
  );
}

class AiCalendarUpdateSheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final String initialPrompt;

  const AiCalendarUpdateSheet({
    super.key,
    required this.selectedDate,
    this.initialPrompt = '',
  });

  @override
  ConsumerState<AiCalendarUpdateSheet> createState() =>
      _AiCalendarUpdateSheetState();
}

class _AiCalendarUpdateSheetState extends ConsumerState<AiCalendarUpdateSheet> {
  late final TextEditingController _promptController;
  bool _isPreviewLoading = false;
  bool _isDecisionLoading = false;
  String? _errorMessage;
  AgentCalendarUpdatePreviewResult? _previewResult;
  AgentCalendarUpdateDecisionResult? _decisionResult;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(
      text: widget.initialPrompt.trim(),
    );
    _promptController.addListener(_handlePromptChanged);
  }

  @override
  void dispose() {
    _promptController
      ..removeListener(_handlePromptChanged)
      ..dispose();
    super.dispose();
  }

  void _handlePromptChanged() {
    if (_previewResult == null &&
        _decisionResult == null &&
        _errorMessage == null) {
      return;
    }

    setState(() {
      _previewResult = null;
      _decisionResult = null;
      _errorMessage = null;
    });
  }

  Future<void> _requestPreview() async {
    final telemetry = ref.read(aiTelemetryServiceProvider);
    final prompt = _promptController.text.trim();
    if (prompt.length < 2) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        reason: '수정할 일정 요청을 조금 더 구체적으로 입력해주세요.',
      );
      setState(() {
        _errorMessage = '수정할 일정 요청을 조금 더 구체적으로 입력해주세요.';
      });
      return;
    }
    final blockedMessage = getPersonalScopeBlockedMessage(
      prompt,
      PersonalAiActionType.calendarUpdate,
    );
    if (blockedMessage != null) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        reason: blockedMessage,
      );
      setState(() {
        _previewResult = null;
        _decisionResult = null;
        _errorMessage = blockedMessage;
      });
      return;
    }

    final userId = ref.read(currentUserProvider)?.uid;
    telemetry.logPreviewRequested(
      toolName: BabbaAiTools.calendarUpdate,
      source: 'calendar_ai_fab',
      capability: BabbaAiCapability.calendarActions,
      extra: {'has_selected_date': true},
    );

    setState(() {
      _isPreviewLoading = true;
      _errorMessage = null;
      _decisionResult = null;
    });

    try {
      final preview = await ref
          .read(babbaSubagentRuntimeServiceProvider)
          .previewPersonalCalendarUpdate(
            userId: userId,
            prompt: prompt,
            source: 'calendar_ai_fab',
            selectedDate: widget.selectedDate,
          );

      if (!mounted) return;
      telemetry.logPreviewRendered(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        requestId: preview.requestId,
      );
      setState(() {
        _previewResult = preview;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logPreviewFailed(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        error: e,
      );
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewLoading = false;
        });
      }
    }
  }

  Future<void> _confirmAndUpdate() async {
    final previewResult = _previewResult;
    if (previewResult == null) return;
    final telemetry = ref.read(aiTelemetryServiceProvider);

    telemetry.logConsentShown(
      toolName: BabbaAiTools.calendarUpdate,
      source: 'calendar_ai_fab',
      capability: BabbaAiCapability.calendarActions,
      requestId: previewResult.requestId,
    );
    final consent = await showAiActionConsentSheet(
      context: context,
      title: 'AI 일정 수정 승인',
      summary: previewResult.summary,
      toolLabel: 'Calendar 수정',
      scopeLabel: '개인 범위',
      approveLabel: '동의하고 수정',
      previewLines: _buildPreviewLines(previewResult.preview),
    );
    if (consent == null) {
      telemetry.logConsentOutcome(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        outcome: 'dismissed',
        requestId: previewResult.requestId,
      );
      return;
    }
    telemetry.logConsentOutcome(
      toolName: BabbaAiTools.calendarUpdate,
      source: 'calendar_ai_fab',
      capability: BabbaAiCapability.calendarActions,
      outcome: consent ? 'approved' : 'denied',
      requestId: previewResult.requestId,
    );

    final userId = ref.read(currentUserProvider)?.uid;
    setState(() {
      _isDecisionLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(babbaSubagentRuntimeServiceProvider)
          .submitPersonalCalendarUpdateDecision(
            userId: userId,
            requestId: previewResult.requestId,
            approved: consent,
          );

      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        outcome: result.status,
        requestId: result.requestId,
        auditId: result.auditId,
      );
      if (result.updated) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _decisionResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.calendarUpdate,
        source: 'calendar_ai_fab',
        capability: BabbaAiCapability.calendarActions,
        outcome: 'failed',
        requestId: previewResult.requestId,
        extra: {'error_type': e.runtimeType.toString()},
      );
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDecisionLoading = false;
        });
      }
    }
  }

  List<String> _buildPreviewLines(AgentCalendarUpdatePreview preview) {
    return [
      '대상 일정: ${preview.originalTitle}',
      '수정 후 제목: ${preview.title}',
      '공개 범위: 나만 보기',
      if ((preview.originalFormattedDueDate ?? '').trim().isNotEmpty)
        '기존 날짜: ${preview.originalFormattedDueDate!.trim()}',
      if ((preview.originalFormattedTimeRange ?? '').trim().isNotEmpty)
        '기존 시간: ${preview.originalFormattedTimeRange!.trim()}',
      if ((preview.formattedDueDate ?? '').trim().isNotEmpty)
        '수정 후 날짜: ${preview.formattedDueDate!.trim()}',
      if ((preview.formattedTimeRange ?? '').trim().isNotEmpty)
        '수정 후 시간: ${preview.formattedTimeRange!.trim()}',
      if ((preview.location ?? '').trim().isNotEmpty)
        '장소: ${preview.location!.trim()}',
      if ((preview.note ?? '').trim().isNotEmpty) '메모: ${preview.note!.trim()}',
      if (preview.reminderLabels.isNotEmpty)
        '알림: ${preview.reminderLabels.join(', ')}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final canSubmit =
        !_isPreviewLoading &&
        !_isDecisionLoading &&
        _promptController.text.trim().length >= 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacingM,
          right: AppTheme.spacingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingM,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: mutedColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Iconsax.edit_2,
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI로 개인 일정 수정하기',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '최근 private 일정 중 하나를 고른 뒤 수정 초안을 만들고, 승인 후에만 반영합니다.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  TextField(
                    controller: _promptController,
                    autofocus: widget.initialPrompt.trim().isEmpty,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '예: 내일 회의 일정을 오전 11시로 옮기고 장소를 2층 회의실로 바꿔줘',
                      filled: true,
                      fillColor:
                          (isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.backgroundLight)
                              .withValues(alpha: 0.85),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canSubmit ? _requestPreview : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          icon: _isPreviewLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Iconsax.flash_1, size: 18),
                          label: Text(
                            _isPreviewLoading ? '수정 초안 생성 중...' : 'AI 수정 초안 보기',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '이번 슬라이스는 private personal 일정만 수정합니다. 공유 일정 쓰기는 아직 막아둡니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedColor,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _CalendarUpdateStatusCard(
                      icon: Iconsax.warning_2,
                      color: AppColors.errorLight,
                      message: _errorMessage!,
                    ),
                  ],
                  if (_decisionResult?.cancelled == true) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const _CalendarUpdateStatusCard(
                      icon: Iconsax.close_circle,
                      color: AppColors.textSecondaryLight,
                      message: 'AI 일정 수정을 취소했어요. 문구를 바꿔 다시 시도할 수 있어요.',
                    ),
                  ],
                  if (_previewResult != null) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    _CalendarUpdatePreviewCard(previewResult: _previewResult!),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDecisionLoading
                                ? null
                                : _confirmAndUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                            ),
                            icon: _isDecisionLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Iconsax.shield_tick, size: 18),
                            label: Text(
                              _isDecisionLoading ? '처리 중...' : '동의하고 개인 일정 수정',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarUpdatePreviewCard extends StatelessWidget {
  final AgentCalendarUpdatePreviewResult previewResult;

  const _CalendarUpdatePreviewCard({required this.previewResult});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = previewResult.preview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.edit_2,
                  color: AppColors.primaryLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  previewResult.summary,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          _CalendarUpdatePreviewRow(
            label: '대상 일정',
            value: preview.originalTitle,
          ),
          _CalendarUpdatePreviewRow(label: '수정 후 제목', value: preview.title),
          _CalendarUpdatePreviewRow(label: '유형', value: preview.eventTypeLabel),
          _CalendarUpdatePreviewRow(label: '공개 범위', value: '나만 보기'),
          if ((preview.originalFormattedDueDate ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '기존 날짜',
              value: preview.originalFormattedDueDate!.trim(),
            ),
          if ((preview.originalFormattedTimeRange ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '기존 시간',
              value: preview.originalFormattedTimeRange!.trim(),
            ),
          if ((preview.formattedDueDate ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '수정 후 날짜',
              value: preview.formattedDueDate!.trim(),
            ),
          if ((preview.formattedTimeRange ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '수정 후 시간',
              value: preview.formattedTimeRange!.trim(),
            ),
          if ((preview.location ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '장소',
              value: preview.location!.trim(),
            ),
          if ((preview.note ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(label: '메모', value: preview.note!.trim()),
          if (preview.reminderLabels.isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '알림',
              value: preview.reminderLabels.join(', '),
            ),
          if ((preview.matchReason ?? '').trim().isNotEmpty)
            _CalendarUpdatePreviewRow(
              label: '매칭 근거',
              value: preview.matchReason!.trim(),
            ),
        ],
      ),
    );
  }
}

class _CalendarUpdatePreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _CalendarUpdatePreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarUpdateStatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _CalendarUpdateStatusCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
