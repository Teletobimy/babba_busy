import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/memo_provider.dart';

/// 빠른 메모 추가 바텀시트
class AddMemoSheet extends ConsumerStatefulWidget {
  const AddMemoSheet({super.key});

  @override
  ConsumerState<AddMemoSheet> createState() => _AddMemoSheetState();
}

class _AddMemoSheetState extends ConsumerState<AddMemoSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
      await ref.read(memoServiceProvider).addMemo(
            title: title,
            content: content,
            categoryId: _selectedCategoryId,
            categoryName: _selectedCategoryName,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모가 저장되었습니다')),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ref.watch(smartMemoCategoriesProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            child: Row(
              children: [
                Icon(
                  Iconsax.note_add,
                  color: AppColors.memoColor,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  '빠른 메모',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Iconsax.close_circle,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // 카테고리 선택
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: Row(
              children: [
                _buildCategoryChip(
                  context,
                  label: '선택 안함',
                  isSelected: _selectedCategoryId == null,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = null;
                      _selectedCategoryName = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...categories.map((category) {
                  final color = _parseColor(category.color);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(
                      context,
                      label: category.name,
                      icon: category.icon,
                      isSelected: _selectedCategoryId == category.id,
                      color: color,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category.id;
                          _selectedCategoryName = category.name;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // 제목 입력
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: TextField(
              controller: _titleController,
              maxLines: 1,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '제목',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                contentPadding: const EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          // 내용 입력 (선택)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            child: TextField(
              controller: _contentController,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: '내용 (선택)',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                contentPadding: const EdgeInsets.all(AppTheme.spacingM),
              ),
            ),
          ),
          // 저장 버튼
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
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
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    String? icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                _getIconData(icon),
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
