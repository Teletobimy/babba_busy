import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/transaction.dart' as models;
import '../../../shared/providers/budget_provider.dart';

/// 거래 카드
class TransactionCard extends ConsumerWidget {
  final models.BudgetTransaction transaction;
  final bool showRecurringBadge;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.showRecurringBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.isIncome;
    final numberFormat = NumberFormat('#,###', 'ko_KR');

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Icon(
          Iconsax.trash,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('거래 삭제'),
            content: const Text('이 거래를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await ref.read(budgetServiceProvider).deleteTransaction(transaction.id);
            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('삭제 실패: $e')),
              );
            }
            return false;
          }
        }

        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              // 카테고리 아이콘
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.getCategoryColor(transaction.category)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.category),
                  color: AppColors.getCategoryColor(transaction.category),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          models.TransactionCategory.getLabel(transaction.category),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (showRecurringBadge && transaction.isRecurring) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.budgetColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '매월',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.budgetColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          DateFormat('M/d').format(transaction.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (transaction.memo != null &&
                            transaction.memo!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              transaction.memo!,
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
              // 금액
              Text(
                '${isIncome ? '+' : '-'}${numberFormat.format(transaction.amount)}원',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isIncome ? AppColors.successLight : AppColors.errorLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'food':
        return Iconsax.coffee;
      case 'transport':
        return Iconsax.car;
      case 'shopping':
        return Iconsax.shopping_bag;
      case 'entertainment':
        return Iconsax.game;
      case 'health':
        return Iconsax.health;
      case 'education':
        return Iconsax.book_1;
      case 'housing':
        return Iconsax.home_2;
      case 'utilities':
        return Iconsax.flash_1;
      case 'income':
        return Iconsax.wallet_add;
      default:
        return Iconsax.more_circle;
    }
  }
}
