import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/color_utils.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/providers/todo_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/utils/date_utils.dart' as date_utils;
import 'add_todo_sheet.dart';

/// 할일 아이템 카드
class TodoItemCard extends ConsumerStatefulWidget {
  final TodoItem todo;
  final FamilyMember? assignee;

  const TodoItemCard({
    super.key,
    required this.todo,
    this.assignee,
  });

  @override
  ConsumerState<TodoItemCard> createState() => _TodoItemCardState();
}

class _TodoItemCardState extends ConsumerState<TodoItemCard> {
  bool _isCompleting = false;

  Future<void> _toggleComplete() async {
    if (_isCompleting) return;

    // 권한 체크
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    if (!widget.todo.canComplete(currentUser.uid)) return;

    final wasCompleted = widget.todo.isCompleted;
    setState(() => _isCompleting = true);

    try {
      final resolvedId = widget.todo.parentTodoId ?? widget.todo.id;
      await ref.read(todoServiceProvider).toggleTodo(
        resolvedId,
        !wasCompleted,
        ownerId: widget.todo.ownerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasCompleted ? '완료 취소됨' : '완료!'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              ref.read(todoServiceProvider).toggleTodo(
                resolvedId,
                wasCompleted, // revert to original state
                ownerId: widget.todo.ownerId,
              );
            },
          ),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  /// 현재 사용자가 이 할일을 완료할 수 있는지 확인
  bool _canComplete() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return false;
    return widget.todo.canComplete(currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberColor = widget.assignee != null
        ? parseHexColor(widget.assignee!.color, fallback: AppColors.memberColors[0])
        : AppColors.memberColors[0];

    return Dismissible(
      key: Key(widget.todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Icon(
          Iconsax.trash,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('할일 삭제'),
            content: const Text('이 할일을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await ref.read(todoServiceProvider).deleteTodo(widget.todo.id);
            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('삭제 실패: $e')),
              );
            }
            return false;
          }
        }

        return false;
      },
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTodoSheet(todoId: widget.todo.parentTodoId ?? widget.todo.id),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: IntrinsicHeight(
              child: Row(
                children: [
                // 색상 바
                Container(
                  width: 4,
                  color: memberColor,
                ),
                // 체크박스 (완료 권한이 있는 경우에만 활성화)
                // 터치 타겟 최소 44x44px 보장
                Semantics(
                  label: '${widget.todo.title} ${widget.todo.isCompleted ? "완료됨" : "미완료"} 토글',
                  button: true,
                  enabled: _canComplete(),
                  child: GestureDetector(
                  onTap: _canComplete() ? _toggleComplete : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.todo.isCompleted
                            ? memberColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.todo.isCompleted
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
                      child: widget.todo.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ).animate().scale(duration: 150.ms)
                          : null,
                    ),
                  ),
                ),
                ),
                // 내용
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingS,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.todo.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  decoration: widget.todo.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: widget.todo.isCompleted
                                      ? (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight)
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!widget.todo.isCompleted && widget.todo.dueDate != null)
                              Builder(builder: (context) {
                                final diff = date_utils.normalizeDate(widget.todo.dueDate!).difference(date_utils.normalizeDate(DateTime.now())).inDays;
                                if (diff > 3) return const SizedBox.shrink();
                                final label = diff == 0 ? 'D-Day' : diff < 0 ? 'D+${-diff}' : 'D-$diff';
                                final badgeColor = diff <= 0 ? AppColors.errorLight : (diff == 1 ? Colors.orange : AppColors.primaryLight);
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(label, style: TextStyle(fontSize: 12, color: badgeColor, fontWeight: FontWeight.w600)),
                                );
                              }),
                          ],
                        ),
                        if (widget.todo.note != null && widget.todo.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Iconsax.note_1,
                                size: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.todo.note!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.todo.dueDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Iconsax.calendar_1,
                                size: 12,
                                color: _isDueToday(widget.todo.dueDate!)
                                    ? AppColors.primaryLight
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDueDate(widget.todo.dueDate!),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: _isDueToday(widget.todo.dueDate!)
                                      ? AppColors.primaryLight
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 담당자 아바타
                if (widget.assignee != null)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: MemberAvatar(
                      member: widget.assignee,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

    if (difference == 0) return '오늘';
    if (difference == 1) return '내일';
    if (difference == -1) return '어제';
    if (difference < 0) return '${-difference}일 전';
    if (difference <= 7) return '$difference일 후';
    return DateFormat('M/d').format(date);
  }
}
