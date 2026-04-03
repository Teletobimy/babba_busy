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

Future<AgentTodoCompleteDecisionResult?> showAiTodoCompleteSheet({
  required BuildContext context,
  String initialPrompt = '',
}) {
  return showModalBottomSheet<AgentTodoCompleteDecisionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AiTodoCompleteSheet(initialPrompt: initialPrompt),
  );
}

class AiTodoCompleteSheet extends ConsumerStatefulWidget {
  final String initialPrompt;

  const AiTodoCompleteSheet({super.key, this.initialPrompt = ''});

  @override
  ConsumerState<AiTodoCompleteSheet> createState() =>
      _AiTodoCompleteSheetState();
}

class _AiTodoCompleteSheetState extends ConsumerState<AiTodoCompleteSheet> {
  late final TextEditingController _promptController;
  bool _isPreviewLoading = false;
  bool _isDecisionLoading = false;
  String? _errorMessage;
  AgentTodoCompletePreviewResult? _previewResult;
  AgentTodoCompleteDecisionResult? _decisionResult;

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
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
        reason: '완료할 할 일을 조금 더 구체적으로 입력해주세요.',
      );
      setState(() {
        _errorMessage = '완료할 할 일을 조금 더 구체적으로 입력해주세요.';
      });
      return;
    }
    final blockedMessage = getPersonalScopeBlockedMessage(
      prompt,
      PersonalAiActionType.todoComplete,
    );
    if (blockedMessage != null) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
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
      toolName: BabbaAiTools.todoComplete,
      source: 'home_quick_add_ai',
      capability: BabbaAiCapability.todoActions,
    );

    setState(() {
      _isPreviewLoading = true;
      _errorMessage = null;
      _decisionResult = null;
    });

    try {
      final preview = await ref
          .read(babbaSubagentRuntimeServiceProvider)
          .previewPersonalTodoComplete(
            userId: userId,
            prompt: prompt,
            source: 'home_quick_add_ai',
          );

      if (!mounted) return;
      telemetry.logPreviewRendered(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
        requestId: preview.requestId,
      );
      setState(() {
        _previewResult = preview;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logPreviewFailed(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
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

  Future<void> _confirmAndComplete() async {
    final previewResult = _previewResult;
    if (previewResult == null) return;
    final telemetry = ref.read(aiTelemetryServiceProvider);

    telemetry.logConsentShown(
      toolName: BabbaAiTools.todoComplete,
      source: 'home_quick_add_ai',
      capability: BabbaAiCapability.todoActions,
      requestId: previewResult.requestId,
    );
    final consent = await showAiActionConsentSheet(
      context: context,
      title: 'AI 할 일 완료 승인',
      summary: previewResult.summary,
      toolLabel: 'Todo 완료',
      scopeLabel: '개인 범위',
      approveLabel: '동의하고 완료',
      previewLines: _buildPreviewLines(previewResult.preview),
    );
    if (consent == null) {
      telemetry.logConsentOutcome(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
        outcome: 'dismissed',
        requestId: previewResult.requestId,
      );
      return;
    }
    telemetry.logConsentOutcome(
      toolName: BabbaAiTools.todoComplete,
      source: 'home_quick_add_ai',
      capability: BabbaAiCapability.todoActions,
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
          .submitPersonalTodoCompleteDecision(
            userId: userId,
            requestId: previewResult.requestId,
            approved: consent,
          );

      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
        outcome: result.status,
        requestId: result.requestId,
        auditId: result.auditId,
        extra: {'already_completed': result.alreadyCompleted},
      );
      if (result.completed) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _decisionResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.todoComplete,
        source: 'home_quick_add_ai',
        capability: BabbaAiCapability.todoActions,
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

  List<String> _buildPreviewLines(AgentTodoCompletePreview preview) {
    return [
      '대상: ${preview.title}',
      if (preview.note != null && preview.note!.trim().isNotEmpty)
        '메모: ${preview.note!.trim()}',
      '공개 범위: 나만 보기',
      if ((preview.formattedDueDate ?? '').trim().isNotEmpty)
        '마감: ${preview.formattedDueDate!.trim()}',
      if ((preview.matchReason ?? '').trim().isNotEmpty)
        '매칭 근거: ${preview.matchReason!.trim()}',
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
                          color: AppColors.chatColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Iconsax.tick_circle,
                          color: AppColors.chatColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI로 개인 할 일 완료하기',
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
                              '자연어 요청을 기준으로 최근 private pending todo를 찾고, 승인 후 완료 처리합니다.',
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
                      hintText: '예: 방금 끝낸 세탁 맡기기 완료 처리해줘',
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
                            backgroundColor: AppColors.chatColor,
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
                              : const Icon(Iconsax.search_normal_1, size: 18),
                          label: Text(
                            _isPreviewLoading ? '대상 찾는 중...' : '완료 대상 찾기',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '최근 private pending todo만 대상으로 삼습니다. 공유 할 일 완료는 아직 막아둡니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedColor,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _CompleteStatusCard(
                      icon: Iconsax.warning_2,
                      color: AppColors.errorLight,
                      message: _errorMessage!,
                    ),
                  ],
                  if (_decisionResult?.cancelled == true) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const _CompleteStatusCard(
                      icon: Iconsax.close_circle,
                      color: AppColors.textSecondaryLight,
                      message: 'AI 할 일 완료를 취소했어요. 문구를 바꿔 다시 찾을 수 있어요.',
                    ),
                  ],
                  if (_previewResult != null) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    _CompletePreviewCard(previewResult: _previewResult!),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDecisionLoading
                                ? null
                                : _confirmAndComplete,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chatColor,
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
                              _isDecisionLoading ? '처리 중...' : '동의하고 완료 처리',
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

class _CompletePreviewCard extends StatelessWidget {
  final AgentTodoCompletePreviewResult previewResult;

  const _CompletePreviewCard({required this.previewResult});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = previewResult.preview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppColors.chatColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.chatColor.withValues(alpha: 0.16)),
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
                  color: AppColors.chatColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.tick_circle,
                  color: AppColors.chatColor,
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
          _CompletePreviewRow(label: '대상', value: preview.title),
          if (preview.note != null && preview.note!.trim().isNotEmpty)
            _CompletePreviewRow(label: '메모', value: preview.note!.trim()),
          _CompletePreviewRow(label: '공개 범위', value: '나만 보기'),
          if ((preview.formattedDueDate ?? '').trim().isNotEmpty)
            _CompletePreviewRow(
              label: '마감',
              value: preview.formattedDueDate!.trim(),
            ),
          if ((preview.matchReason ?? '').trim().isNotEmpty)
            _CompletePreviewRow(
              label: '매칭 근거',
              value: preview.matchReason!.trim(),
            ),
        ],
      ),
    );
  }
}

class _CompletePreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _CompletePreviewRow({required this.label, required this.value});

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

class _CompleteStatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _CompleteStatusCard({
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
