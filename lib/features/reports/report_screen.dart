import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/report_provider.dart';
import '../../shared/providers/streak_provider.dart';
import 'widgets/completion_chart.dart';
import 'widgets/member_stats_card.dart';

/// 가족 리포트 화면
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final summary = ref.watch(reportSummaryProvider);
    final streak = ref.watch(streakProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 리포트'),
        centerTitle: true,
        actions: [
          // 기간 전환
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.week, label: Text('주간')),
              ButtonSegment(value: ReportPeriod.month, label: Text('월간')),
            ],
            selected: {period},
            onSelectionChanged: (s) =>
                ref.read(reportPeriodProvider.notifier).state = s.first,
            style: SegmentedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요약 카드
            Row(
              children: [
                _SummaryTile(
                  icon: Iconsax.tick_circle,
                  label: '완료',
                  value: '${summary.totalCompleted}',
                  color: AppColors.successLight,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  icon: Iconsax.task_square,
                  label: '진행 중',
                  value: '${summary.totalPending}',
                  color: AppColors.primaryLight,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  icon: Iconsax.flash_1,
                  label: '연속',
                  value: '$streak일',
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SummaryTile(
                  icon: Iconsax.chart_2,
                  label: '일 평균',
                  value: summary.avgPerDay.toStringAsFixed(1),
                  color: AppColors.accentLight,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _SummaryTile(
                  icon: Iconsax.star_1,
                  label: '최고 요일',
                  value: summary.bestWeekdayName,
                  color: AppColors.calendarColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // 일별 완료 차트
            Text(
              '일별 완료 수',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            const SizedBox(
              height: 200,
              child: CompletionChart(),
            ),

            const SizedBox(height: AppTheme.spacingXL),

            // 멤버별 통계
            Text(
              '멤버별 기여도',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            const MemberStatsCard(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
