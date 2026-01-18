import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_group.dart';
import '../../../shared/providers/smart_provider.dart';

/// 캘린더 필터 Bottom Sheet
class CalendarFilterSheet extends ConsumerWidget {
  const CalendarFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarGroups = ref.watch(smartCalendarGroupsProvider);
    final selectedGroups = ref.watch(selectedCalendarGroupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '캘린더 선택',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // 전체 선택
                      TextButton(
                        onPressed: () {
                          ref.read(selectedCalendarGroupsProvider.notifier).state =
                              calendarGroups.map((g) => g.id).toSet();
                        },
                        child: const Text('전체 선택'),
                      ),
                      // 전체 해제
                      TextButton(
                        onPressed: () {
                          ref.read(selectedCalendarGroupsProvider.notifier).state = {};
                        },
                        child: const Text('전체 해제'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            
            // 캘린더 그룹 목록
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Column(
                children: calendarGroups.map((group) {
                  final isSelected = selectedGroups.contains(group.id);
                  final groupColor = _parseColor(group.color);
                  
                  return _CalendarGroupTile(
                    group: group,
                    isSelected: isSelected,
                    groupColor: groupColor,
                    isDark: isDark,
                    onToggle: () {
                      final current = Set<String>.from(selectedGroups);
                      if (isSelected) {
                        current.remove(group.id);
                      } else {
                        current.add(group.id);
                      }
                      ref.read(selectedCalendarGroupsProvider.notifier).state = current;
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            // 확인 버튼
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.calendarColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.calendarColor;
    }
  }
}

class _CalendarGroupTile extends StatelessWidget {
  final CalendarGroup group;
  final bool isSelected;
  final Color groupColor;
  final bool isDark;
  final VoidCallback onToggle;

  const _CalendarGroupTile({
    required this.group,
    required this.isSelected,
    required this.groupColor,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: isSelected
              ? Border.all(color: groupColor, width: 2)
              : Border.all(
                  color: (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight)
                      .withValues(alpha: 0.2),
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // 체크박스
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? groupColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        width: 1.5,
                      ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // 캘린더 색상 인디케이터
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: groupColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            
            // 캘린더 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            
            // 아이콘
            Icon(
              _getIconForType(group.type),
              size: 20,
              color: groupColor,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(CalendarGroupType type) {
    switch (type) {
      case CalendarGroupType.personal:
        return Iconsax.user;
      case CalendarGroupType.family:
        return Iconsax.home;
      case CalendarGroupType.friends:
        return Iconsax.people;
      case CalendarGroupType.work:
        return Iconsax.briefcase;
      case CalendarGroupType.other:
        return Iconsax.calendar;
    }
  }
}

/// 캘린더 필터 버튼 (헤더에서 사용)
class CalendarFilterButton extends ConsumerWidget {
  const CalendarFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarGroups = ref.watch(smartCalendarGroupsProvider);
    final selectedGroups = ref.watch(selectedCalendarGroupsProvider);
    final allSelected = selectedGroups.length == calendarGroups.length;

    return Stack(
      children: [
        IconButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const CalendarFilterSheet(),
            );
          },
          icon: const Icon(Iconsax.filter),
        ),
        // 필터 적용됨 인디케이터
        if (!allSelected && selectedGroups.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.calendarColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
