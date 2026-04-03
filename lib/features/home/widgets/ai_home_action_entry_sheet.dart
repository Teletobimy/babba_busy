import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

enum AiHomeActionEntryMode { todoCreate, todoComplete, reminderCreate }

Future<AiHomeActionEntryMode?> showAiHomeActionEntrySheet({
  required BuildContext context,
  String initialPrompt = '',
  required bool todoActionsEnabled,
  String? todoActionsDisabledReason,
  required bool reminderActionsEnabled,
  String? reminderActionsDisabledReason,
}) {
  return showModalBottomSheet<AiHomeActionEntryMode>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _AiHomeActionEntrySheet(
      initialPrompt: initialPrompt,
      todoActionsEnabled: todoActionsEnabled,
      todoActionsDisabledReason: todoActionsDisabledReason,
      reminderActionsEnabled: reminderActionsEnabled,
      reminderActionsDisabledReason: reminderActionsDisabledReason,
    ),
  );
}

class _AiHomeActionEntrySheet extends StatelessWidget {
  final String initialPrompt;
  final bool todoActionsEnabled;
  final String? todoActionsDisabledReason;
  final bool reminderActionsEnabled;
  final String? reminderActionsDisabledReason;

  const _AiHomeActionEntrySheet({
    required this.initialPrompt,
    required this.todoActionsEnabled,
    required this.todoActionsDisabledReason,
    required this.reminderActionsEnabled,
    required this.reminderActionsDisabledReason,
  });

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
                  'AI 빠른 액션',
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
                  initialPrompt.trim().isEmpty
                      ? '개인 할 일 또는 개인 리마인더 액션을 고르세요.'
                      : '입력한 문장을 기준으로 실행할 개인 액션을 고르세요.',
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
                const SizedBox(height: AppTheme.spacingL),
                _EntryTile(
                  icon: Iconsax.magic_star,
                  color: AppColors.primaryLight,
                  title: '개인 할 일 생성',
                  subtitle: '자연어 요청으로 private todo 초안을 만들고 승인 후 저장합니다.',
                  enabled: todoActionsEnabled,
                  disabledReason: todoActionsDisabledReason,
                  onTap: todoActionsEnabled
                      ? () => Navigator.of(
                          context,
                        ).pop(AiHomeActionEntryMode.todoCreate)
                      : null,
                ),
                const SizedBox(height: AppTheme.spacingS),
                _EntryTile(
                  icon: Iconsax.tick_circle,
                  color: AppColors.chatColor,
                  title: '개인 할 일 완료',
                  subtitle: '최근 private pending todo 중 하나를 찾아 승인 후 완료 처리합니다.',
                  enabled: todoActionsEnabled,
                  disabledReason: todoActionsDisabledReason,
                  onTap: todoActionsEnabled
                      ? () => Navigator.of(
                          context,
                        ).pop(AiHomeActionEntryMode.todoComplete)
                      : null,
                ),
                const SizedBox(height: AppTheme.spacingS),
                _EntryTile(
                  icon: Iconsax.notification,
                  color: Colors.orange,
                  title: '개인 리마인더 생성',
                  subtitle: '개인 리마인더 초안을 만들고 승인 후 reminder queue에 등록합니다.',
                  enabled: reminderActionsEnabled,
                  disabledReason: reminderActionsDisabledReason,
                  onTap: reminderActionsEnabled
                      ? () => Navigator.of(
                          context,
                        ).pop(AiHomeActionEntryMode.reminderCreate)
                      : null,
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
  final bool enabled;
  final String? disabledReason;
  final VoidCallback? onTap;

  const _EntryTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.disabledReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: enabled ? 0.1 : 0.07),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: effectiveColor),
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
                  if (!enabled && (disabledReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      disabledReason!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
