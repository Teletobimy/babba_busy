import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/memo.dart';
import '../../shared/models/memo_category.dart';
import '../../shared/providers/memo_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../services/ai/ai_api_service.dart';
import 'memo_category_utils.dart';
import 'widgets/create_memo_category_dialog.dart';

/// 메모 상세/편집 화면
class MemoDetailScreen extends ConsumerStatefulWidget {
  final Memo? memo; // null이면 새 메모 작성

  const MemoDetailScreen({super.key, this.memo});

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  List<String> _selectedTags = const [];
  bool _isPinned = false;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _aiAnalysis;
  String? _aiSummary;
  List<String> _aiValidationPoints = const [];
  String? _aiSuggestedCategory;
  List<String> _aiSuggestedTags = const [];
  DateTime? _analyzedAt;
  bool _isAiStale = false;
  bool _hasChanges = false;

  bool get _isNewMemo => widget.memo == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController = TextEditingController(
      text: widget.memo?.content ?? '',
    );
    _selectedCategoryId = widget.memo?.categoryId;
    _selectedCategoryName = widget.memo?.categoryName;
    _selectedTags = List<String>.from(widget.memo?.tags ?? const []);
    _isPinned = widget.memo?.isPinned ?? false;
    _aiAnalysis = widget.memo?.aiAnalysis;
    _analyzedAt = widget.memo?.analyzedAt;
    _restoreAiSectionsFromPersisted();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasSavedAi = _aiAnalysis != null && _aiAnalysis!.isNotEmpty;
    if (!_hasChanges || (hasSavedAi && !_isAiStale)) {
      setState(() {
        _hasChanges = true;
        if (hasSavedAi) {
          _isAiStale = true;
          _analyzedAt = null;
        }
      });
    }
  }

  bool _hasTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _selectedTags.any((item) => item.trim().toLowerCase() == normalized);
  }

  List<String> get _unappliedSuggestedTags => _aiSuggestedTags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty && !_hasTag(tag))
      .toList();

  void _toggleTag(String tag) {
    final normalized = tag.trim();
    if (normalized.isEmpty) return;

    setState(() {
      final index = _selectedTags.indexWhere(
        (item) => item.trim().toLowerCase() == normalized.toLowerCase(),
      );
      if (index >= 0) {
        _selectedTags = List<String>.from(_selectedTags)..removeAt(index);
      } else {
        _selectedTags = List<String>.from(_selectedTags)..add(normalized);
      }
      _hasChanges = true;
    });
  }

  void _applyAiSuggestedTags() {
    if (_unappliedSuggestedTags.isEmpty) return;

    setState(() {
      _selectedTags = List<String>.from(_selectedTags)
        ..addAll(_unappliedSuggestedTags);
      _hasChanges = true;
    });
  }

  void _restoreAiSectionsFromPersisted() {
    final raw = _aiAnalysis;
    if (raw == null || raw.trim().isEmpty) return;

    String? summary;
    List<String> validationPoints = const [];

    for (final line in raw.split('\n').map((line) => line.trim())) {
      if (line.startsWith('요약:')) {
        summary = line.substring('요약:'.length).trim();
      } else if (line.startsWith('검증:')) {
        validationPoints = line
            .substring('검증:'.length)
            .split('/')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }

    _aiSummary = summary;
    _aiValidationPoints = validationPoints;
  }

  Future<void> _saveMemo() async {
    final titleInput = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (titleInput.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메모 제목 또는 내용을 입력해주세요')));
      return;
    }

    final title = deriveMemoTitle(
      titleInput: titleInput,
      contentInput: content,
    );
    final aiAnalysisToSave = _isAiStale ? null : _aiAnalysis;
    final analyzedAtToSave = _isAiStale ? null : _analyzedAt;

    setState(() => _isLoading = true);

    try {
      final memoService = ref.read(memoServiceProvider);

      if (_isNewMemo) {
        await memoService.addMemo(
          title: title,
          content: content,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          tags: _selectedTags,
          isPinned: _isPinned,
          aiAnalysis: aiAnalysisToSave,
          analyzedAt: analyzedAtToSave,
        );
      } else {
        await memoService.updateMemo(
          widget.memo!.id,
          title: title,
          content: content,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          tags: _selectedTags,
          isPinned: _isPinned,
          aiAnalysis: aiAnalysisToSave,
          analyzedAt: analyzedAtToSave,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNewMemo ? '메모가 저장되었습니다' : '메모가 수정되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMemo() async {
    if (_isNewMemo) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(memoServiceProvider).deleteMemo(widget.memo!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('메모가 삭제되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  Future<void> _analyzeWithAI() async {
    final content = _contentController.text.trim();
    if (content.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용이 너무 짧아 분석할 수 없습니다 (최소 20자)')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final aiApiService = ref.read(aiApiServiceProvider);
      final result = await aiApiService.analyzeMemo(
        userId: user.uid,
        content: content,
        categoryName: _selectedCategoryName,
      );

      final analysisText = result.analysis.trim();
      final summaryText = result.summary.trim();
      final validationPoints = result.validationPoints
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      final suggestedCategory = result.suggestedCategory?.trim();
      final suggestedTags = result.suggestedTags
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      final composedAnalysis = _composeAiAnalysisText(
        analysis: analysisText,
        summary: summaryText,
        validationPoints: validationPoints,
      );

      if (composedAnalysis.isEmpty && summaryText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('AI 분석을 수행할 수 없습니다')));
        }
      } else {
        final categories = ref.read(smartMemoCategoriesProvider);
        final matchedCategory = findMemoCategoryByName(
          categories,
          suggestedCategory,
        );

        setState(() {
          _aiAnalysis = composedAnalysis.isNotEmpty
              ? composedAnalysis
              : summaryText;
          _aiSummary = summaryText;
          _aiValidationPoints = validationPoints;
          _aiSuggestedCategory =
              suggestedCategory != null && suggestedCategory.isNotEmpty
              ? suggestedCategory
              : null;
          _aiSuggestedTags = suggestedTags;
          _analyzedAt = DateTime.now();
          _isAiStale = false;
          if (matchedCategory != null) {
            _selectedCategoryId = matchedCategory.id;
            _selectedCategoryName = matchedCategory.name;
          }
          _hasChanges = true;
        });
      }
    } on AiApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('분석 실패: $e')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('분석 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showCategoryPicker() {
    final categories = ref.read(smartMemoCategoriesProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPickerSheet(
        categories: categories,
        selectedCategoryId: _selectedCategoryId,
        onCreateCategory: () async {
          final created = await showCreateMemoCategoryDialog(
            context: context,
            ref: ref,
          );
          if (!mounted || created == null) return;

          setState(() {
            _selectedCategoryId = created.id;
            _selectedCategoryName = created.name;
            _hasChanges = true;
            if (_aiAnalysis != null && _aiAnalysis!.isNotEmpty) {
              _isAiStale = true;
              _analyzedAt = null;
            }
          });

          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        onSelect: (category) {
          setState(() {
            if (category == null) {
              _selectedCategoryId = null;
              _selectedCategoryName = null;
            } else {
              _selectedCategoryId = category.id;
              _selectedCategoryName = category.name;
            }
            _hasChanges = true;
            if (_aiAnalysis != null && _aiAnalysis!.isNotEmpty) {
              _isAiStale = true;
              _analyzedAt = null;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(memoCategoryBootstrapProvider);
    final categories = ref.watch(smartMemoCategoriesProvider);
    final selectedCategory = findMemoCategoryById(
      categories,
      _selectedCategoryId,
    );
    final selectedCategoryLabel =
        selectedCategory?.name ?? _selectedCategoryName;
    final categoryColor = parseMemoCategoryColor(selectedCategory?.color);
    final categoryIconName = selectedCategory?.icon ?? 'note_1';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (_hasChanges) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('변경사항'),
                  content: const Text('저장하지 않은 변경사항이 있습니다. 나가시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('나가기'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Iconsax.arrow_left),
        ),
        title: Text(_isNewMemo ? '새 메모' : '메모 편집'),
        actions: [
          // 카테고리 선택
          IconButton(
            onPressed: _showCategoryPicker,
            icon: Icon(
              memoCategoryIconData(categoryIconName),
              color: categoryColor,
            ),
            tooltip: '카테고리',
          ),
          // 고정 토글
          IconButton(
            onPressed: () {
              setState(() {
                _isPinned = !_isPinned;
                _hasChanges = true;
              });
            },
            icon: Icon(
              _isPinned ? Iconsax.attach_circle5 : Iconsax.attach_circle,
              color: _isPinned ? categoryColor : null,
            ),
            tooltip: _isPinned ? '고정 해제' : '상단 고정',
          ),
          // AI 분석
          IconButton(
            onPressed: _isAnalyzing ? null : _analyzeWithAI,
            icon: _isAnalyzing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryLight,
                    ),
                  )
                : Icon(Iconsax.magic_star, color: AppColors.primaryLight),
            tooltip: 'AI 분석',
          ),
          // 삭제 (기존 메모만)
          if (!_isNewMemo)
            IconButton(
              onPressed: _deleteMemo,
              icon: Icon(Iconsax.trash, color: AppColors.errorLight),
              tooltip: '삭제',
            ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 표시
          if (selectedCategoryLabel != null && selectedCategoryLabel.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingS,
              ),
              color: categoryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    memoCategoryIconData(categoryIconName),
                    size: 16,
                    color: categoryColor,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    selectedCategoryLabel,
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // 편집 영역
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 입력 (필수)
                  TextField(
                    controller: _titleController,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '제목',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(height: AppTheme.spacingL),
                  // 내용 입력 (선택)
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: '내용 (선택)',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  // AI 분석 결과
                  if (_isAiStale &&
                      _aiAnalysis != null &&
                      _aiAnalysis!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingL),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '내용이 변경되어 AI 결과가 최신이 아닙니다. 다시 분석해 주세요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                  if (_aiAnalysis != null && _aiAnalysis!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXL),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Iconsax.magic_star,
                                size: 16,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Text(
                                'AI 요약/검증',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_aiSummary != null && _aiSummary!.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingS),
                            Text(
                              _aiSummary!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                          if (_aiValidationPoints.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              '검증 포인트',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            ..._aiValidationPoints.map(
                              (point) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Iconsax.tick_circle,
                                      size: 14,
                                      color: AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if ((_aiSuggestedCategory != null &&
                                  _aiSuggestedCategory!.isNotEmpty) ||
                              _aiSuggestedTags.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            if (_aiSuggestedTags.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _unappliedSuggestedTags.isEmpty
                                      ? null
                                      : _applyAiSuggestedTags,
                                  icon: const Icon(
                                    Iconsax.tick_circle,
                                    size: 14,
                                  ),
                                  label: const Text('추천 태그 적용'),
                                ),
                              ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (_aiSuggestedCategory != null &&
                                    _aiSuggestedCategory!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.memoColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSmall,
                                      ),
                                    ),
                                    child: Text(
                                      '추천 카테고리: ${_aiSuggestedCategory!}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.memoColor,
                                          ),
                                    ),
                                  ),
                                ..._aiSuggestedTags
                                    .take(5)
                                    .map(
                                      (tag) => GestureDetector(
                                        onTap: () => _toggleTag(tag),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _hasTag(tag)
                                                ? AppColors.sage[100]
                                                : AppColors.primaryLight
                                                      .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSmall,
                                            ),
                                            border: Border.all(
                                              color: _hasTag(tag)
                                                  ? AppColors.sage[400]!
                                                  : AppColors.primaryLight
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                            ),
                                          ),
                                          child: Text(
                                            '#$tag${_hasTag(tag) ? ' 적용됨' : ''}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _hasTag(tag)
                                                      ? AppColors.sage[700]
                                                      : AppColors.primaryLight,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ],
                          if (_selectedTags.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              '적용 태그',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _selectedTags.map((tag) {
                                return GestureDetector(
                                  onTap: () => _toggleTag(tag),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.memoColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSmall,
                                      ),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.memoColor,
                                          ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (_aiSummary == null ||
                              _aiSummary!.isEmpty ||
                              _aiAnalysis!.trim() != _aiSummary!.trim()) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              _aiAnalysis!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 저장 버튼
          Container(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacingL,
              AppTheme.spacingM,
              AppTheme.spacingL,
              MediaQuery.of(context).padding.bottom + AppTheme.spacingM,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveMemo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.memoColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isNewMemo ? '저장' : '수정',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카테고리 선택 시트
class _CategoryPickerSheet extends StatelessWidget {
  final List<MemoCategory> categories;
  final String? selectedCategoryId;
  final Function(MemoCategory?) onSelect;
  final Future<void> Function()? onCreateCategory;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    this.onCreateCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Text(
              '카테고리 선택',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onCreateCategory != null)
            ListTile(
              leading: Icon(Iconsax.add_circle, color: AppColors.memoColor),
              title: const Text('카테고리 추가'),
              onTap: () => onCreateCategory!(),
            ),
          if (onCreateCategory != null) const Divider(),
          // 선택 안함
          ListTile(
            leading: Icon(
              Iconsax.close_circle,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            title: const Text('선택 안함'),
            trailing: selectedCategoryId == null
                ? Icon(Iconsax.tick_circle5, color: AppColors.primaryLight)
                : null,
            onTap: () => onSelect(null),
          ),
          const Divider(),
          // 카테고리 목록
          ...categories.map((category) {
            final color = parseMemoCategoryColor(category.color);
            final isSelected = category.id == selectedCategoryId;
            return ListTile(
              leading: Icon(memoCategoryIconData(category.icon), color: color),
              title: Text(category.name),
              trailing: isSelected
                  ? Icon(Iconsax.tick_circle5, color: color)
                  : null,
              onTap: () => onSelect(category),
            );
          }),
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppTheme.spacingL,
          ),
        ],
      ),
    );
  }
}

String _composeAiAnalysisText({
  required String analysis,
  required String summary,
  required List<String> validationPoints,
}) {
  final buffer = StringBuffer();
  if (summary.isNotEmpty) {
    buffer.writeln('요약: $summary');
  }
  if (validationPoints.isNotEmpty) {
    buffer.writeln('검증: ${validationPoints.join(' / ')}');
  }
  if (analysis.isNotEmpty) {
    buffer.writeln('인사이트: $analysis');
  }
  return buffer.toString().trim();
}
