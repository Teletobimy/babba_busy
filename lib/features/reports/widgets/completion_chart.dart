import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/report_provider.dart';

/// 일별 완료 수 막대 차트
class CompletionChart extends ConsumerWidget {
  const CompletionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyMap = ref.watch(dailyCompletionProvider);
    final period = ref.watch(reportPeriodProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 날짜순 정렬
    final sortedEntries = dailyMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.isEmpty) {
      return const Center(child: Text('데이터가 없어요'));
    }

    final maxY = sortedEntries
        .map((e) => e.value.toDouble())
        .fold<double>(1, (max, v) => v > max ? v : max);

    return BarChart(
      BarChartData(
        maxY: maxY + 1,
        barGroups: sortedEntries.asMap().entries.map((entry) {
          final i = entry.key;
          final value = entry.value.value.toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: value,
                color: value > 0 ? AppColors.primaryLight : (isDark ? Colors.white12 : Colors.black12),
                width: period == ReportPeriod.week ? 24 : 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= sortedEntries.length) return const SizedBox.shrink();
                final date = sortedEntries[i].key;
                // 주간: 요일, 월간: 날짜
                final label = period == ReportPeriod.week
                    ? DateFormat('E', 'ko_KR').format(date)
                    : (i % 5 == 0 ? DateFormat('d').format(date) : '');
                return Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = sortedEntries[group.x].key;
              return BarTooltipItem(
                '${DateFormat('M/d').format(date)}\n${rod.toY.toInt()}개 완료',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}
