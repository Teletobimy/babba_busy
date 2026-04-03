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

Future<AgentNoteUpdateDecisionResult?> showAiNoteUpdateSheet({
  required BuildContext context,
  String initialPrompt = '',
}) {
  return showModalBottomSheet<AgentNoteUpdateDecisionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AiNoteUpdateSheet(initialPrompt: initialPrompt),
  );
}

class AiNoteUpdateSheet extends ConsumerStatefulWidget {
  final String initialPrompt;

  const AiNoteUpdateSheet({super.key, this.initialPrompt = ''});

  @override
  ConsumerState<AiNoteUpdateSheet> createState() => _AiNoteUpdateSheetState();
}

class _AiNoteUpdateSheetState extends ConsumerState<AiNoteUpdateSheet> {
  late final TextEditingController _promptController;
  bool _isPreviewLoading = false;
  bool _isDecisionLoading = false;
  String? _errorMessage;
  AgentNoteUpdatePreviewResult? _previewResult;
  AgentNoteUpdateDecisionResult? _decisionResult;

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
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        reason: '수정할 메모 요청을 조금 더 구체적으로 입력해주세요.',
      );
      setState(() {
        _errorMessage = '수정할 메모 요청을 조금 더 구체적으로 입력해주세요.';
      });
      return;
    }
    final blockedMessage = getPersonalScopeBlockedMessage(
      prompt,
      PersonalAiActionType.noteUpdate,
    );
    if (blockedMessage != null) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
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
      toolName: BabbaAiTools.noteUpdate,
      source: 'memo_ai_fab',
      capability: BabbaAiCapability.noteActions,
    );
    setState(() {
      _isPreviewLoading = true;
      _errorMessage = null;
      _decisionResult = null;
    });

    try {
      final preview = await ref
          .read(babbaSubagentRuntimeServiceProvider)
          .previewPersonalNoteUpdate(
            userId: userId,
            prompt: prompt,
            source: 'memo_ai_fab',
          );

      if (!mounted) return;
      telemetry.logPreviewRendered(
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        requestId: preview.requestId,
      );
      setState(() {
        _previewResult = preview;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logPreviewFailed(
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
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
      toolName: BabbaAiTools.noteUpdate,
      source: 'memo_ai_fab',
      capability: BabbaAiCapability.noteActions,
      requestId: previewResult.requestId,
    );
    final consent = await showAiActionConsentSheet(
      context: context,
      title: 'AI 메모 수정 승인',
      summary: previewResult.summary,
      toolLabel: 'Notes 수정',
      scopeLabel: '개인 범위',
      approveLabel: '동의하고 수정',
      previewLines: _buildPreviewLines(previewResult.preview),
    );
    if (consent == null) {
      telemetry.logConsentOutcome(
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        outcome: 'dismissed',
        requestId: previewResult.requestId,
      );
      return;
    }
    telemetry.logConsentOutcome(
      toolName: BabbaAiTools.noteUpdate,
      source: 'memo_ai_fab',
      capability: BabbaAiCapability.noteActions,
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
          .submitPersonalNoteUpdateDecision(
            userId: userId,
            requestId: previewResult.requestId,
            approved: consent,
          );

      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
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
        toolName: BabbaAiTools.noteUpdate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
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

  List<String> _buildPreviewLines(AgentNoteUpdatePreview preview) {
    return [
      '대상 메모: ${preview.originalTitle}',
      '수정 후 제목: ${preview.title}',
      if ((preview.originalCategoryName ?? '').trim().isNotEmpty)
        '기존 카테고리: ${preview.originalCategoryName!.trim()}',
      if ((preview.categoryName ?? '').trim().isNotEmpty)
        '수정 후 카테고리: ${preview.categoryName!.trim()}',
      if (preview.tags.isNotEmpty)
        '태그: ${preview.tags.map((tag) => '#$tag').join(', ')}',
      '상단 고정: ${preview.isPinned ? '켜짐' : '꺼짐'}',
      if (preview.content.trim().isNotEmpty) '본문: ${preview.content.trim()}',
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
                              'AI로 개인 메모 수정하기',
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
                              '최근 메모 중 하나를 고른 뒤 수정 초안을 만들고, 승인 후에만 반영합니다.',
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
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText:
                          '예: 방금 만든 회의 메모 제목을 주간 회의 요약으로 바꾸고 액션 아이템 3개를 정리해줘',
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
                    '이번 슬라이스는 개인 메모 수정만 지원합니다. 공유 쓰기와 다중 메모 변경은 아직 열지 않습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedColor,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _NoteUpdateStatusCard(
                      icon: Iconsax.warning_2,
                      color: AppColors.errorLight,
                      message: _errorMessage!,
                    ),
                  ],
                  if (_decisionResult?.cancelled == true) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const _NoteUpdateStatusCard(
                      icon: Iconsax.close_circle,
                      color: AppColors.textSecondaryLight,
                      message: 'AI 메모 수정을 취소했어요. 문구를 바꿔 다시 시도할 수 있어요.',
                    ),
                  ],
                  if (_previewResult != null) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    _NoteUpdatePreviewCard(previewResult: _previewResult!),
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
                              _isDecisionLoading ? '처리 중...' : '동의하고 개인 메모 수정',
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

class _NoteUpdatePreviewCard extends StatelessWidget {
  final AgentNoteUpdatePreviewResult previewResult;

  const _NoteUpdatePreviewCard({required this.previewResult});

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
          _NoteUpdatePreviewRow(label: '대상 메모', value: preview.originalTitle),
          _NoteUpdatePreviewRow(label: '수정 후 제목', value: preview.title),
          if ((preview.originalCategoryName ?? '').trim().isNotEmpty)
            _NoteUpdatePreviewRow(
              label: '기존 카테고리',
              value: preview.originalCategoryName!.trim(),
            ),
          if ((preview.categoryName ?? '').trim().isNotEmpty)
            _NoteUpdatePreviewRow(
              label: '수정 후 카테고리',
              value: preview.categoryName!.trim(),
            ),
          if (preview.tags.isNotEmpty)
            _NoteUpdatePreviewRow(
              label: '태그',
              value: preview.tags.map((tag) => '#$tag').join(', '),
            ),
          _NoteUpdatePreviewRow(
            label: '고정',
            value: preview.isPinned ? '켜짐' : '꺼짐',
          ),
          if (preview.content.trim().isNotEmpty)
            _NoteUpdatePreviewRow(label: '본문', value: preview.content.trim()),
          if ((preview.matchReason ?? '').trim().isNotEmpty)
            _NoteUpdatePreviewRow(
              label: '매칭 근거',
              value: preview.matchReason!.trim(),
            ),
        ],
      ),
    );
  }
}

class _NoteUpdatePreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _NoteUpdatePreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
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

class _NoteUpdateStatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _NoteUpdateStatusCard({
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
