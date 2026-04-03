import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

enum AiCalendarActionEntryMode { create, update }

Future<AiCalendarActionEntryMode?> showAiCalendarActionEntrySheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<AiCalendarActionEntryMode>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AiCalendarActionEntrySheet(),
  );
}

class _AiCalendarActionEntrySheet extends StatelessWidget {
  const _AiCalendarActionEntrySheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(AppTheme.spacingL),
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
                Text(
                  'AI Calendar 액션',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '생성 또는 수정 액션을 고르세요.',
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
                const SizedBox(height: AppTheme.spacingL),
                _EntryTile(
                  icon: Iconsax.calendar_add,
                  color: AppColors.calendarColor,
                  title: '개인 일정 생성',
                  subtitle: '자연어 요청으로 private 일정 초안을 만들고 승인 후 저장합니다.',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(AiCalendarActionEntryMode.create),
                ),
                const SizedBox(height: AppTheme.spacingS),
                _EntryTile(
                  icon: Iconsax.edit_2,
                  color: AppColors.primaryLight,
                  title: '개인 일정 수정',
                  subtitle: '최근 private 일정 중 하나를 찾아 수정 초안을 만들고 승인 후 반영합니다.',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(AiCalendarActionEntryMode.update),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
