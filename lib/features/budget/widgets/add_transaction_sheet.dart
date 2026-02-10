import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/transaction.dart' as models;
import '../../../shared/providers/budget_provider.dart';

/// 거래 추가 바텀 시트
class AddTransactionSheet extends ConsumerStatefulWidget {
  final models.BudgetTransaction? transaction;

  const AddTransactionSheet({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isExpense = true;
  String _selectedCategory = 'food';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    if (transaction == null) return;

    _isExpense = transaction.isExpense;
    _selectedCategory = transaction.isIncome ? 'income' : transaction.category;
    _selectedDate = transaction.date;
    _isRecurring = transaction.isRecurring;
    _amountController.text = NumberFormat('#,###').format(transaction.amount);
    _memoController.text = transaction.memo ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);

    try {
      final budgetService = ref.read(budgetServiceProvider);
      final memo = _memoController.text.trim();
      final type = _isExpense ? 'expense' : 'income';
      final category = _isExpense ? _selectedCategory : 'income';
      final isRecurring = _isExpense ? _isRecurring : false;
      final recurringType = isRecurring ? 'monthly' : '';

      if (_isEditMode) {
        await budgetService.updateTransaction(
          widget.transaction!.id,
          type: type,
          amount: amount,
          category: category,
          memo: memo,
          date: _selectedDate,
          isRecurring: isRecurring,
          recurringType: recurringType,
        );
      } else {
        await budgetService.addTransaction(
          type: type,
          amount: amount,
          category: category,
          memo: memo.isEmpty ? null : memo,
          date: _selectedDate,
          isRecurring: isRecurring,
          recurringType: isRecurring ? 'monthly' : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final minDate = DateTime(2000, 1, 1);
    final maxDate = DateTime.now().add(const Duration(days: 3650));
    var initialDate = _selectedDate;
    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    }
    if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.spacingL,
          right: AppTheme.spacingL,
          top: AppTheme.spacingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 핸들바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            Text(
              _isEditMode ? '거래 수정' : '거래 추가',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 지출/수입 토글
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.backgroundDark
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: '지출',
                      isSelected: _isExpense,
                      color: AppColors.errorLight,
                      onTap: () => setState(() => _isExpense = true),
                    ),
                  ),
                  Expanded(
                    child: _TypeButton(
                      label: '수입',
                      isSelected: !_isExpense,
                      color: AppColors.successLight,
                      onTap: () => setState(() => _isExpense = false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 금액 입력
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _isExpense
                    ? AppColors.errorLight
                    : AppColors.successLight,
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsSeparatorFormatter(),
              ],
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color:
                      (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.5),
                ),
                suffixText: '원',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 카테고리 선택 (지출일 때만)
            if (_isExpense) ...[
              Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppTheme.spacingS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: models.TransactionCategory.expenseCategories.map((
                  category,
                ) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.getCategoryColor(category)
                            : AppColors.getCategoryColor(
                                category,
                              ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        models.TransactionCategory.getLabel(category),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.getCategoryColor(category),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],

            // 날짜 선택
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('yyyy년 M월 d일').format(_selectedDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 메모
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                hintText: '메모 (선택)',
                prefixIcon: Icon(Iconsax.note_1),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 고정 지출 토글
            if (_isExpense)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.repeat, size: 20),
                    const SizedBox(width: 12),
                    const Text('매월 반복'),
                    const Spacer(),
                    Switch(
                      value: _isRecurring,
                      onChanged: (value) =>
                          setState(() => _isRecurring = value),
                      activeTrackColor: AppColors.budgetColor.withValues(
                        alpha: 0.5,
                      ),
                      activeThumbColor: AppColors.budgetColor,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.spacingL),

            // 추가 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isExpense
                      ? AppColors.errorLight
                      : AppColors.successLight,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode
                            ? '수정 저장'
                            : (_isExpense ? '지출 추가' : '수입 추가'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final number = int.tryParse(newValue.text.replaceAll(',', ''));
    if (number == null) return oldValue;

    final formatted = NumberFormat('#,###').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
