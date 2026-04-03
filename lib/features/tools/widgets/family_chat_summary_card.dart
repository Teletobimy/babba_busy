import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ai/ai_api_service.dart';

class FamilyChatSummaryCard extends StatelessWidget {
  final bool isLoading;
  final FamilyChatSummaryResult? result;
  final String? errorText;
  final bool isStale;
  final VoidCallback? onRetry;

  const FamilyChatSummaryCard({
    super.key,
    required this.isLoading,
    this.result,
    this.errorText,
    this.isStale = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingM,
        AppTheme.spacingM,
        AppTheme.spacingM,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppColors.chatColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.magic_star, size: 16, color: AppColors.chatColor),
              const SizedBox(width: 8),
              Text(
                'AI 대화 요약',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.chatColor,
                ),
              ),
              const Spacer(),
              if (result != null)
                Text(
                  '최근 ${result!.messageCount}개',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: textSecondary),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          if (isLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '가족 채팅을 읽고 요약하는 중이에요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          else if (result != null) ...[
            Text(
              result!.summary,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            if (result!.highlights.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingS),
              ...result!.highlights.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.chatColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  label: '${result!.participantCount}명 참여',
                  isDark: isDark,
                ),
                if (result!.cached) _MetaChip(label: '캐시 사용', isDark: isDark),
                if (isStale)
                  _MetaChip(label: '새 대화 있음', isDark: isDark, warn: true),
              ],
            ),
          ] else if (errorText != null) ...[
            Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Iconsax.refresh, size: 16),
                label: const Text('다시 시도'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.chatColor,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool warn;

  const _MetaChip({
    required this.label,
    required this.isDark,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = warn ? Colors.orange : AppColors.chatColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
