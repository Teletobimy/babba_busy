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

Future<AgentNoteCreateDecisionResult?> showAiNoteCreateSheet({
  required BuildContext context,
  String initialPrompt = '',
}) {
  return showModalBottomSheet<AgentNoteCreateDecisionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AiNoteCreateSheet(initialPrompt: initialPrompt),
  );
}

class AiNoteCreateSheet extends ConsumerStatefulWidget {
  final String initialPrompt;

  const AiNoteCreateSheet({super.key, this.initialPrompt = ''});

  @override
  ConsumerState<AiNoteCreateSheet> createState() => _AiNoteCreateSheetState();
}

class _AiNoteCreateSheetState extends ConsumerState<AiNoteCreateSheet> {
  late final TextEditingController _promptController;
  bool _isPreviewLoading = false;
  bool _isDecisionLoading = false;
  String? _errorMessage;
  AgentNoteCreatePreviewResult? _previewResult;
  AgentNoteCreateDecisionResult? _decisionResult;

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
        toolName: BabbaAiTools.noteCreate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        reason: '메모 요청을 조금 더 구체적으로 입력해주세요.',
      );
      setState(() {
        _errorMessage = '메모 요청을 조금 더 구체적으로 입력해주세요.';
      });
      return;
    }
    final blockedMessage = getPersonalScopeBlockedMessage(
      prompt,
      PersonalAiActionType.noteCreate,
    );
    if (blockedMessage != null) {
      telemetry.logPreviewBlocked(
        toolName: BabbaAiTools.noteCreate,
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
      toolName: BabbaAiTools.noteCreate,
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
          .previewPersonalNoteCreate(
            userId: userId,
            prompt: prompt,
            source: 'memo_ai_fab',
          );

      if (!mounted) return;
      telemetry.logPreviewRendered(
        toolName: BabbaAiTools.noteCreate,
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
        toolName: BabbaAiTools.noteCreate,
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

  Future<void> _confirmAndCreate() async {
    final previewResult = _previewResult;
    if (previewResult == null) return;
    final telemetry = ref.read(aiTelemetryServiceProvider);

    telemetry.logConsentShown(
      toolName: BabbaAiTools.noteCreate,
      source: 'memo_ai_fab',
      capability: BabbaAiCapability.noteActions,
      requestId: previewResult.requestId,
    );
    final consent = await showAiActionConsentSheet(
      context: context,
      title: 'AI 메모 생성 승인',
      summary: previewResult.summary,
      toolLabel: 'Notes 생성',
      scopeLabel: '개인 범위',
      approveLabel: '동의하고 생성',
      previewLines: _buildPreviewLines(previewResult.preview),
    );
    if (consent == null) {
      telemetry.logConsentOutcome(
        toolName: BabbaAiTools.noteCreate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        outcome: 'dismissed',
        requestId: previewResult.requestId,
      );
      return;
    }
    telemetry.logConsentOutcome(
      toolName: BabbaAiTools.noteCreate,
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
          .submitPersonalNoteCreateDecision(
            userId: userId,
            requestId: previewResult.requestId,
            approved: consent,
          );

      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.noteCreate,
        source: 'memo_ai_fab',
        capability: BabbaAiCapability.noteActions,
        outcome: result.status,
        requestId: result.requestId,
        auditId: result.auditId,
      );
      if (result.created) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _decisionResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      telemetry.logActionResult(
        toolName: BabbaAiTools.noteCreate,
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

  List<String> _buildPreviewLines(AgentNoteCreatePreview preview) {
    return [
      '제목: ${preview.title}',
      if ((preview.categoryName ?? '').trim().isNotEmpty)
        '카테고리: ${preview.categoryName!.trim()}',
      if (preview.tags.isNotEmpty)
        '태그: ${preview.tags.map((tag) => '#$tag').join(', ')}',
      if (preview.isPinned) '상단 고정: 켜짐',
      if (preview.content.trim().isNotEmpty) '본문: ${preview.content.trim()}',
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
                          color: AppColors.memoColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Iconsax.note_add,
                          color: AppColors.memoColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI로 개인 메모 만들기',
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
                              '자연어 요청으로 메모 초안을 만들고, 승인 후에만 저장합니다.',
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
                      hintText: '예: 오늘 회의 메모 초안 만들어줘. 액션 아이템 3개와 후속 질문도 적어줘',
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
                            backgroundColor: AppColors.memoColor,
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
                            _isPreviewLoading ? '초안 생성 중...' : 'AI 메모 초안 보기',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '이번 슬라이스는 개인 메모 생성만 지원합니다. 기존 메모 수정과 공유 쓰기는 아직 열지 않습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: mutedColor,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    _NoteStatusCard(
                      icon: Iconsax.warning_2,
                      color: AppColors.errorLight,
                      message: _errorMessage!,
                    ),
                  ],
                  if (_decisionResult?.cancelled == true) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    const _NoteStatusCard(
                      icon: Iconsax.close_circle,
                      color: AppColors.textSecondaryLight,
                      message: 'AI 메모 생성을 취소했어요. 문구를 바꿔 다시 시도할 수 있어요.',
                    ),
                  ],
                  if (_previewResult != null) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    _NotePreviewCard(previewResult: _previewResult!),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDecisionLoading
                                ? null
                                : _confirmAndCreate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.memoColor,
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
                              _isDecisionLoading ? '처리 중...' : '동의하고 개인 메모 생성',
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

class _NotePreviewCard extends StatelessWidget {
  final AgentNoteCreatePreviewResult previewResult;

  const _NotePreviewCard({required this.previewResult});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = previewResult.preview;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppColors.memoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.memoColor.withValues(alpha: 0.18)),
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
                  color: AppColors.memoColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.note_add,
                  color: AppColors.memoColor,
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
          _NotePreviewRow(label: '제목', value: preview.title),
          if ((preview.categoryName ?? '').trim().isNotEmpty)
            _NotePreviewRow(label: '카테고리', value: preview.categoryName!.trim()),
          if (preview.tags.isNotEmpty)
            _NotePreviewRow(
              label: '태그',
              value: preview.tags.map((tag) => '#$tag').join(', '),
            ),
          _NotePreviewRow(label: '고정', value: preview.isPinned ? '켜짐' : '꺼짐'),
          if (preview.content.trim().isNotEmpty)
            _NotePreviewRow(label: '본문', value: preview.content.trim()),
        ],
      ),
    );
  }
}

class _NotePreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _NotePreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
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

class _NoteStatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _NoteStatusCard({
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
