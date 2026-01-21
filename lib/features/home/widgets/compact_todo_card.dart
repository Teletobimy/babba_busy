import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/providers/todo_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 메인 화면용 컴팩트 할일 카드 (접고 펼 수 있음)
class CompactTodoCard extends ConsumerStatefulWidget {
  final TodoItem todo;
  final FamilyMember? assignee;

  const CompactTodoCard({
    super.key,
    required this.todo,
    this.assignee,
  });

  @override
  ConsumerState<CompactTodoCard> createState() => _CompactTodoCardState();
}

class _CompactTodoCardState extends ConsumerState<CompactTodoCard>
    with SingleTickerProviderStateMixin {
  bool _isCompleting = false;
  bool _isExpanded = false;
  bool _showCompletionEffect = false;

  /// 현재 사용자가 이 할일을 완료할 수 있는지 확인
  bool _canComplete() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;
    return widget.todo.canComplete(currentUser.uid);
  }

  Future<void> _toggleComplete() async {
    if (_isCompleting) return;

    // 권한 체크
    if (!_canComplete()) return;

    final wasCompleted = widget.todo.isCompleted;

    setState(() => _isCompleting = true);

    // 완료 체크 시 애니메이션 효과
    if (!wasCompleted) {
      setState(() => _showCompletionEffect = true);
      // 체크 애니메이션 후 잠시 대기
      await Future.delayed(const Duration(milliseconds: 300));
    }

    try {
      await ref.read(todoServiceProvider).toggleTodo(
        widget.todo.id,
        !widget.todo.isCompleted,
        ownerId: widget.todo.ownerId,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
          _showCompletionEffect = false;
        });
      }
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberColor = widget.assignee != null
        ? _parseColor(widget.assignee!.color)
        : AppColors.memberColors[0];

    final hasDetails = (widget.todo.note != null && widget.todo.note!.isNotEmpty) ||
        widget.todo.dueDate != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 메인 행 (항상 표시)
            IntrinsicHeight(
              child: Row(
                children: [
                  // 색상 바
                  Container(
                    width: 4,
                    color: memberColor,
                  ),
                  // 체크박스 (완료 권한이 있는 경우에만 활성화)
                  // 터치 타겟 최소 44x44px 보장
                  GestureDetector(
                    onTap: _canComplete() ? _toggleComplete : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingM,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: (widget.todo.isCompleted || _showCompletionEffect)
                              ? memberColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (widget.todo.isCompleted || _showCompletionEffect)
                                ? memberColor
                                : _canComplete()
                                    ? (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight)
                                        .withValues(alpha: 0.5)
                                    : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight)
                                        .withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: (widget.todo.isCompleted || _showCompletionEffect)
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ).animate().scale(duration: 150.ms)
                            : null,
                      ),
                    ),
                  ),
                  // 제목
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingS,
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              decoration: (widget.todo.isCompleted || _showCompletionEffect)
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: (widget.todo.isCompleted || _showCompletionEffect)
                                  ? (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                  : (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight),
                            ),
                        child: Text(
                          widget.todo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  // 담당자 아바타
                  if (widget.assignee != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: MemberAvatar(
                        member: widget.assignee,
                        size: 24,
                      ),
                    ),
                  // 접고 펴기 버튼
                  if (hasDetails)
                    GestureDetector(
                      onTap: _toggleExpand,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingS,
                        ),
                        child: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Iconsax.arrow_down_1,
                            size: 18,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: AppTheme.spacingS),
                ],
              ),
            ),
            // 확장 영역 (노트, 마감일)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(isDark),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(
        left: 4 + AppTheme.spacingS + 22 + AppTheme.spacingS, // 색상바 + 체크박스 영역
        right: AppTheme.spacingM,
        bottom: AppTheme.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.todo.note != null && widget.todo.note!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Iconsax.note_1,
                  size: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.todo.note!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (widget.todo.dueDate != null) ...[
            if (widget.todo.note != null && widget.todo.note!.isNotEmpty)
              const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Iconsax.calendar_1,
                  size: 14,
                  color: _isDueToday(widget.todo.dueDate!)
                      ? AppColors.primaryLight
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDueDate(widget.todo.dueDate!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _isDueToday(widget.todo.dueDate!)
                            ? AppColors.primaryLight
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                        fontWeight: _isDueToday(widget.todo.dueDate!)
                            ? FontWeight.w600
                            : null,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return AppColors.memberColors[0];
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.memberColors[0];
    }
  }

  bool _isDueToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = targetDate.difference(today).inDays;

    if (difference == 0) return '오늘까지';
    if (difference == 1) return '내일까지';
    if (difference == -1) return '어제 마감';
    if (difference < 0) return '${-difference}일 지남';
    if (difference <= 7) return '$difference일 남음';
    return DateFormat('M월 d일까지').format(date);
  }
}
