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
  bool _isPinned = false;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _aiAnalysis;
  bool _hasChanges = false;

  bool get _isNewMemo => widget.memo == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo?.title ?? '');
    _contentController = TextEditingController(text: widget.memo?.content ?? '');
    _selectedCategoryId = widget.memo?.categoryId;
    _selectedCategoryName = widget.memo?.categoryName;
    _isPinned = widget.memo?.isPinned ?? false;
    _aiAnalysis = widget.memo?.aiAnalysis;

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
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveMemo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    final content = _contentController.text.trim();

    setState(() => _isLoading = true);

    try {
      final memoService = ref.read(memoServiceProvider);

      if (_isNewMemo) {
        await memoService.addMemo(
          title: title,
          content: content,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          isPinned: _isPinned,
        );
      } else {
        await memoService.updateMemo(
          widget.memo!.id,
          title: title,
          content: content,
          categoryId: _selectedCategoryId,
          categoryName: _selectedCategoryName,
          isPinned: _isPinned,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모가 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
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

      if (result.analysis.isNotEmpty) {
        setState(() {
          _aiAnalysis = result.analysis;
          _hasChanges = true;
        });

        // 기존 메모인 경우 분석 결과 저장
        if (!_isNewMemo) {
          await ref.read(memoServiceProvider).saveAiAnalysis(
                widget.memo!.id,
                result.analysis,
              );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI 분석을 수행할 수 없습니다')),
          );
        }
      }
    } on AiApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: $e')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: $e')),
        );
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
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(_selectedCategoryId);

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
              if (confirmed == true && mounted) {
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
              _getIconData(_getCategoryIcon(_selectedCategoryId)),
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
                : Icon(
                    Iconsax.magic_star,
                    color: AppColors.primaryLight,
                  ),
            tooltip: 'AI 분석',
          ),
          // 삭제 (기존 메모만)
          if (!_isNewMemo)
            IconButton(
              onPressed: _deleteMemo,
              icon: Icon(
                Iconsax.trash,
                color: AppColors.errorLight,
              ),
              tooltip: '삭제',
            ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 표시
          if (_selectedCategoryName != null)
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
                    _getIconData(_getCategoryIcon(_selectedCategoryId)),
                    size: 16,
                    color: categoryColor,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    _selectedCategoryName!,
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
                  if (_aiAnalysis != null && _aiAnalysis!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXL),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                                'AI 분석',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            _aiAnalysis!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
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
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
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

  Color _getCategoryColor(String? categoryId) {
    switch (categoryId) {
      case 'diary':
        return const Color(0xFFFFB74D);
      case 'note':
        return const Color(0xFF64B5F6);
      case 'idea':
        return const Color(0xFFBA68C8);
      case 'todo_memo':
        return const Color(0xFF4DB6AC);
      default:
        return const Color(0xFF64B5F6);
    }
  }

  String _getCategoryIcon(String? categoryId) {
    switch (categoryId) {
      case 'diary':
        return 'book_1';
      case 'note':
        return 'note_1';
      case 'idea':
        return 'lamp_charge';
      case 'todo_memo':
        return 'task_square';
      default:
        return 'note_1';
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'book_1':
        return Iconsax.book_1;
      case 'note_1':
        return Iconsax.note_1;
      case 'lamp_charge':
        return Iconsax.lamp_charge;
      case 'task_square':
        return Iconsax.task_square;
      default:
        return Iconsax.note;
    }
  }
}

/// 카테고리 선택 시트
class _CategoryPickerSheet extends StatelessWidget {
  final List<MemoCategory> categories;
  final String? selectedCategoryId;
  final Function(MemoCategory?) onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
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
            final color = _parseColor(category.color);
            final isSelected = category.id == selectedCategoryId;
            return ListTile(
              leading: Icon(
                _getIconData(category.icon ?? 'note'),
                color: color,
              ),
              title: Text(category.name),
              trailing: isSelected
                  ? Icon(Iconsax.tick_circle5, color: color)
                  : null,
              onTap: () => onSelect(category),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppTheme.spacingL),
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF64B5F6);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'book_1':
        return Iconsax.book_1;
      case 'note_1':
        return Iconsax.note_1;
      case 'lamp_charge':
        return Iconsax.lamp_charge;
      case 'task_square':
        return Iconsax.task_square;
      default:
        return Iconsax.note;
    }
  }
}
