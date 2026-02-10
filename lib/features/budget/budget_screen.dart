import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/models/transaction.dart' as models;
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/add_transaction_sheet.dart';
import 'widgets/transaction_card.dart';

/// 가계부 탭 Provider
final budgetTabProvider = StateProvider<int>((ref) => 0);

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(budgetTabProvider);

    // Smart Provider 사용
    final transactions = ref.watch(smartThisMonthTransactionsProvider);
    final summary = ref.watch(smartMonthSummaryProvider);
    final recurringTransactions = ref.watch(smartRecurringTransactionsProvider);
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '가계부',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ).animate().fadeIn(duration: 300.ms),
                  Text(
                    DateFormat('yyyy년 M월').format(DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // 요약 카드
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  children: [
                    // 수입/지출/잔액
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            label: '수입',
                            amount: summary.totalIncome,
                            color: AppColors.successLight,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color:
                              (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                  .withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: _SummaryItem(
                            label: '지출',
                            amount: summary.totalExpense,
                            color: AppColors.errorLight,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color:
                              (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight)
                                  .withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: _SummaryItem(
                            label: '잔액',
                            amount: summary.balance,
                            color: summary.balance >= 0
                                ? AppColors.budgetColor
                                : AppColors.errorLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    // 카테고리별 차트
                    if (summary.categoryExpenses.isNotEmpty) ...[
                      SizedBox(
                        height: 140,
                        child: Row(
                          children: [
                            // 파이 차트
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  sections: summary.categoryExpenses.entries
                                      .map(
                                        (entry) => PieChartSectionData(
                                          value: entry.value.toDouble(),
                                          color: AppColors.getCategoryColor(
                                            entry.key,
                                          ),
                                          radius: 25,
                                          showTitle: false,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            // 범례
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: summary.categoryExpenses.entries
                                    .take(5)
                                    .map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: _LegendItem(
                                          color: AppColors.getCategoryColor(
                                            entry.key,
                                          ),
                                          label:
                                              models
                                                  .TransactionCategory.getLabel(
                                                entry.key,
                                              ),
                                          amount: entry.value,
                                          percentage: summary
                                              .getCategoryPercentage(entry.key),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        child: Text(
                          '이번 달 지출 내역이 없습니다',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 탭 바
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: '거래 내역',
                      count: transactions.length,
                      isSelected: currentTab == 0,
                      onTap: () =>
                          ref.read(budgetTabProvider.notifier).state = 0,
                    ),
                    _TabButton(
                      label: '고정 지출',
                      count: recurringTransactions.length,
                      isSelected: currentTab == 1,
                      onTap: () =>
                          ref.read(budgetTabProvider.notifier).state = 1,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 리스트
            Expanded(
              child: currentTab == 0
                  ? _TransactionList(
                      transactions: transactions,
                      members: members,
                    )
                  : _RecurringList(
                      transactions: recurringTransactions,
                      members: members,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context),
        backgroundColor: AppColors.budgetColor,
        child: const Icon(Iconsax.add),
      ).animate().scale(delay: 500.ms, duration: 300.ms),
    );
  }

  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###', 'ko_KR');

    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${numberFormat.format(amount)}원',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int amount;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,###', 'ko_KR');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(
          '${numberFormat.format(amount)}원',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Text(
          '(${percentage.toStringAsFixed(0)}%)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.budgetColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.budgetColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.budgetColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<models.BudgetTransaction> transactions;
  final List members;

  const _TransactionList({required this.transactions, required this.members});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const TransactionEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return TransactionCard(
              transaction: transaction,
              onTap: () => _showEditTransactionSheet(context, transaction),
            )
            .animate()
            .fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: 50 * (index % 10)),
            )
            .slideX(begin: 0.05);
      },
    );
  }

  void _showEditTransactionSheet(
    BuildContext context,
    models.BudgetTransaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transaction: transaction),
    );
  }
}

class _RecurringList extends StatelessWidget {
  final List<models.BudgetTransaction> transactions;
  final List members;

  const _RecurringList({required this.transactions, required this.members});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const EmptyState(
        icon: Iconsax.repeat,
        title: '고정 지출이 없습니다',
        subtitle: '매월 반복되는 지출을 등록해보세요',
      );
    }

    // 총 고정 지출 계산
    final totalRecurring = transactions
        .where((t) => t.type == 'expense')
        .fold<int>(0, (sum, t) => sum + t.amount);
    final numberFormat = NumberFormat('#,###', 'ko_KR');

    return Column(
      children: [
        // 총 고정 지출
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppColors.budgetColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '월 고정 지출 합계',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${numberFormat.format(totalRecurring)}원',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.budgetColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionCard(
                    transaction: transaction,
                    showRecurringBadge: true,
                    onTap: () =>
                        _showEditTransactionSheet(context, transaction),
                  )
                  .animate()
                  .fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: 50 * index),
                  )
                  .slideX(begin: 0.05);
            },
          ),
        ),
      ],
    );
  }

  void _showEditTransactionSheet(
    BuildContext context,
    models.BudgetTransaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(transaction: transaction),
    );
  }
}
