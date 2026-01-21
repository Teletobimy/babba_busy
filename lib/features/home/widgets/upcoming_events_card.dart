import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/providers/smart_provider.dart';

/// 다가오는 일정 카드
class UpcomingEventsCard extends ConsumerWidget {
  const UpcomingEventsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Smart Provider 사용
    final todos = ref.watch(smartUpcomingTodosProvider);
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (todos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '다가오는 일정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () => context.go('/calendar'),
              child: const Text('전체보기'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        ...todos.take(3).map((todo) {
          // 참여자 ID 수집
          final participantIds = {...todo.participants};
          if (todo.assigneeId != null) {
            participantIds.add(todo.assigneeId!);
          }

          final participantColors = participantIds
              .map((id) {
                try {
                  final member = members.firstWhere((m) => m.id == id);
                  return _parseColor(member.color);
                } catch (e) {
                  return AppColors.memberColors[0];
                }
              })
              .toList();

          // 날짜 결정
          final displayDate = todo.startTime ?? todo.dueDate ?? DateTime.now();

          return AppCard(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
            onTap: () => context.go('/calendar'),
            child: Row(
              children: [
                // 날짜 표시
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.calendarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('d').format(displayDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.calendarColor,
                        ),
                      ),
                      Text(
                        DateFormat('E', 'ko_KR').format(displayDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.calendarColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 일정 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              todo.title,
                              style: Theme.of(context).textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (todo.isPersonal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '개인',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock,
                            size: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            !todo.hasTime
                                ? '시간 미정'
                                : DateFormat('a h:mm', 'ko_KR').format(displayDate),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (todo.location != null && todo.location!.isNotEmpty) ...[
                            const SizedBox(width: 8),
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
                        ],
                      ),
                    ],
                  ),
                ),
                // 참여자 아바타
                if (participantColors.isNotEmpty)
                  SizedBox(
                    width: 56,
                    height: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _buildParticipantAvatars(participantColors, isDark),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildParticipantAvatars(List<Color> colors, bool isDark) {
    final widgets = <Widget>[];
    final colorList = colors.take(3).toList();
    for (int i = 0; i < colorList.length; i++) {
      widgets.add(
        Transform.translate(
          offset: Offset(-i * 8.0, 0),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorList[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                width: 2,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
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
}
