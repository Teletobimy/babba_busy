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
import '../../../shared/utils/encouragement_messages.dart';
import '../../../shared/providers/streak_provider.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../todo/widgets/add_todo_sheet.dart';
import '../../../shared/services/analytics_service.dart';

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
        widget.todo.parentTodoId ?? widget.todo.id,
        !widget.todo.isCompleted,
        ownerId: widget.todo.ownerId,
      );
      AnalyticsService().logTodoCompleted(
        todoId: widget.todo.id,
        wasUndo: wasCompleted,
      );
      if (mounted) {
        final streak = ref.read(streakProvider);
        final isFirst = !wasCompleted && ref.read(smartTodayCompletedTodosProvider).length <= 1;
        final hour = DateTime.now().hour;
        final message = wasCompleted
            ? '완료 취소됨'
            : (hour >= 23 || hour < 5)
                ? EncouragementMessages.getLateNightMessage()
                : EncouragementMessages.getCompletionMessage(streak: streak, isFirst: isFirst);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => ref.read(todoServiceProvider).toggleTodo(
              widget.todo.parentTodoId ?? widget.todo.id,
              wasCompleted,
              ownerId: widget.todo.ownerId,
            ),
          ),
        ));
      }
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

  void _openEditSheet(BuildContext context) {
    // 반복 인스턴스는 부모 todo ID로 편집
    final todoId = widget.todo.parentTodoId ?? widget.todo.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTodoSheet(todoId: todoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberColor = widget.assignee != null
        ? parseHexColor(widget.assignee!.color, fallback: AppColors.memberColors[0])
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
                    decoration: BoxDecoration(
                      gradient: widget.todo.eventType == TodoEventType.event
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [memberColor.withValues(alpha: 0.6), memberColor],
                            )
                          : null,
                      color: widget.todo.eventType == TodoEventType.event
                          ? null
                          : memberColor.withValues(alpha: widget.todo.eventType == TodoEventType.todo ? 0.8 : 1.0),
                    ),
                  ),
                  // 체크박스 (완료 권한이 있는 경우에만 활성화)
                  // 터치 타겟 최소 44x44px 보장
                  Semantics(
                    label: '${widget.todo.title} ${widget.todo.isCompleted ? "완료됨" : "미완료"}',
                    button: true,
                    enabled: _canComplete(),
                    child: GestureDetector(
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
                              ).animate(target: _isCompleting ? 1 : 0).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.05, 1.05),
                                duration: 150.ms,
                              ).then().shimmer(
                                duration: 400.ms,
                                color: Colors.white.withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                    ),
                  ),
                  ),
                  // 제목 (탭하면 편집 시트 열기)
                  Expanded(
                    child: Semantics(
                    label: '${widget.todo.title} 편집',
                    button: true,
                    child: GestureDetector(
                      onTap: () => _openEditSheet(context),
                      behavior: HitTestBehavior.opaque,
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.todo.title,
                                  maxLines: 1,
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
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(label, style: TextStyle(fontSize: 9, color: badgeColor, fontWeight: FontWeight.w600)),
                                  );
                                }),
                              if (widget.todo.eventType != TodoEventType.todo)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.todo.eventType == TodoEventType.schedule
                                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                                        : AppColors.calendarColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.todo.eventType.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.todo.eventType == TodoEventType.schedule
                                          ? AppColors.primaryOnWhite
                                          : AppColors.calendarColorOnWhite,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                    Semantics(
                      label: _isExpanded ? '접기' : '펼치기',
                      button: true,
                      child: GestureDetector(
                        onTap: _toggleExpand,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                            vertical: AppTheme.spacingM,
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
          if (widget.todo.dueDate != null || widget.todo.startTime != null) ...[
            if (widget.todo.note != null && widget.todo.note!.isNotEmpty)
              const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  widget.todo.hasTime ? Iconsax.clock : Iconsax.calendar_1,
                  size: 14,
                  color: _getDateColor(isDark),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDateTime(),
                    style: _getDateTextStyle(context, isDark),
                  ),
                ),
              ],
            ),
          ],
        ],
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

    if (difference == 0) return '오늘까지';
    if (difference == 1) return '내일까지';
    if (difference == -1) return '어제 마감';
    if (difference < 0) return '${-difference}일 지남';
    if (difference <= 7) return '$difference일 남음';
    return DateFormat('M월 d일까지').format(date);
  }

  String _formatDateTime() {
    if (widget.todo.hasTime && widget.todo.startTime != null) {
      final start = DateFormat('M월 d일 a h:mm', 'ko_KR').format(widget.todo.startTime!);
      if (widget.todo.endTime != null) {
        final end = DateFormat('a h:mm', 'ko_KR').format(widget.todo.endTime!);
        return '$start - $end';
      }
      return start;
    } else if (widget.todo.dueDate != null) {
      return _formatDueDate(widget.todo.dueDate!);
    }
    return '';
  }

  Color _getDateColor(bool isDark) {
    if (widget.todo.dueDate != null && _isDueToday(widget.todo.dueDate!)) {
      return AppColors.primaryLight;
    }
    return isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  }

  TextStyle? _getDateTextStyle(BuildContext context, bool isDark) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
      color: _getDateColor(isDark),
      fontWeight: (widget.todo.dueDate != null && _isDueToday(widget.todo.dueDate!))
          ? FontWeight.w600
          : null,
    );
  }
}
