import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/todo_item.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 할일 카드 (캘린더용)
class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final List<dynamic> members;

  const TodoCard({
    super.key,
    required this.todo,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 참여자 목록
    final participantIds = {...todo.participants};
    if (todo.assigneeId != null) {
      participantIds.add(todo.assigneeId!);
    }
    final participants = members
        .where((m) => participantIds.contains(m.id))
        .cast<FamilyMember>()
        .toList();

    return Container(
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
                color: _getEventTypeColor(todo.eventType),
              ),
              // 내용
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 시간
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock,
                            size: 14,
                            color: _getEventTypeColor(todo.eventType),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeRange(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getEventTypeColor(todo.eventType),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 제목
                      Text(
                        todo.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 설명
                      if (todo.note != null && todo.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          todo.note!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 장소
                      if (todo.location != null && todo.location!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                todo.location!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // 참여자
                      if (participants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              ...participants.take(4).map((member) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: MemberAvatar(
                                      member: member,
                                      size: 24,
                                    ),
                                  )),
                              if (participants.length > 4)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.backgroundDark
                                        : AppColors.backgroundLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${participants.length - 4}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRange() {
    if (!todo.hasTime) {
      return '시간 미정';
    }

    if (todo.startTime != null) {
      final startStr = DateFormat('HH:mm').format(todo.startTime!);
      if (todo.endTime != null) {
        final endStr = DateFormat('HH:mm').format(todo.endTime!);
        return '$startStr - $endStr';
      }
      return startStr;
    }

    return '시간 미정';
  }

  Color _getEventTypeColor(TodoEventType eventType) {
    switch (eventType) {
      case TodoEventType.event:
        return AppColors.calendarColor;
      case TodoEventType.todo:
        return AppColors.todoColor;
      case TodoEventType.personal:
        return AppColors.primaryLight;
    }
  }
}
