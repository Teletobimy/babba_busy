import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';

/// 빈 상태 위젯
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 할일 빈 상태
class TodoEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const TodoEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Iconsax.task_square,
      title: '할 일이 없습니다',
      subtitle: '새로운 할 일을 추가해보세요!',
      action: onAdd != null
          ? ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Iconsax.add),
              label: const Text('할 일 추가'),
            )
          : null,
    );
  }
}

/// 이벤트 빈 상태
class EventEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const EventEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Iconsax.calendar,
      title: '일정이 없습니다',
      subtitle: '새로운 일정을 등록해보세요!',
      action: onAdd != null
          ? ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Iconsax.add),
              label: const Text('일정 추가'),
            )
          : null,
    );
  }
}

/// 추억 빈 상태
class MemoryEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const MemoryEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Iconsax.gallery,
      title: '아직 추억이 없습니다',
      subtitle: '가족과 함께한 순간을 기록해보세요!',
      action: onAdd != null
          ? ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Iconsax.add),
              label: const Text('추억 추가'),
            )
          : null,
    );
  }
}

/// 거래 빈 상태
class TransactionEmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const TransactionEmptyState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Iconsax.receipt,
      title: '거래 내역이 없습니다',
      subtitle: '수입이나 지출을 기록해보세요!',
      action: onAdd != null
          ? ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Iconsax.add),
              label: const Text('거래 추가'),
            )
          : null,
    );
  }
}
