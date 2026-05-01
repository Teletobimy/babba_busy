import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ai/ai_api_service.dart';
import '../../shared/widgets/app_card.dart';

final _auditHistoryProvider = FutureProvider.autoDispose<AgentAuditLogListResult>(
  (ref) async {
    final service = ref.watch(aiApiServiceProvider);
    return service.getRecentAgentAuditLogs(limit: 30);
  },
);

class AiAuditHistoryScreen extends ConsumerWidget {
  const AiAuditHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncAudit = ref.watch(_auditHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 활동 기록'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(_auditHistoryProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_auditHistoryProvider);
          await ref.read(_auditHistoryProvider.future);
        },
        child: asyncAudit.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(_auditHistoryProvider),
          ),
          data: (result) {
            if (result.items.isEmpty) {
              return _EmptyView(isDark: isDark);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: result.items.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacingS),
              itemBuilder: (context, index) {
                if (index == result.items.length) {
                  return _RetentionFooter(isDark: isDark);
                }
                return _AuditEntryCard(entry: result.items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final AgentAuditLogEntry entry;

  const _AuditEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final toolMeta = _toolMeta(entry.tool, entry.action);
    final timestampLabel = _formatTimestamp(entry.executedAt ?? entry.createdAt);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: toolMeta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(toolMeta.icon, size: 18, color: toolMeta.color),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolMeta.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.targetLabel != null &&
                        entry.targetLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.targetLabel!.trim(),
                        style: TextStyle(fontSize: 13, color: mutedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (timestampLabel != null)
                Text(
                  timestampLabel,
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
            ],
          ),
          if (entry.prompt != null && entry.prompt!.trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight)
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${entry.prompt!.trim()}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: mutedColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              _StatusChip(
                label: entry.consentApproved ? '승인' : '거부',
                color: entry.consentApproved
                    ? AppColors.successLight
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              _StatusChip(
                label: _executionStatusLabel(entry.executionStatus),
                color: _executionStatusColor(entry.executionStatus),
              ),
              const Spacer(),
              if (entry.scope.isNotEmpty)
                Text(
                  _scopeLabel(entry.scope),
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool isDark;

  const _EmptyView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return ListView(
      // RefreshIndicator 작동을 위해 비어있어도 ListView 사용
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: 80,
      ),
      children: [
        Icon(Iconsax.shield_search, size: 48, color: mutedColor),
        const SizedBox(height: AppTheme.spacingM),
        Center(
          child: Text(
            'AI 활동 기록이 아직 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: mutedColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI로 할 일·일정·메모·리마인더를 만들면 여기에 기록되어 30일 동안 보관됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: mutedColor),
        ),
      ],
    );
  }
}

class _RetentionFooter extends StatelessWidget {
  final bool isDark;

  const _RetentionFooter({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingM,
      ),
      child: Text(
        'AI 활동 기록은 최근 30일까지 보관되며, 이후 자동 삭제됩니다.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, height: 1.5, color: mutedColor),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: 80,
      ),
      children: [
        const Icon(
          Iconsax.warning_2,
          size: 48,
          color: AppColors.errorLight,
        ),
        const SizedBox(height: AppTheme.spacingM),
        Center(
          child: Text(
            'AI 활동 기록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.errorLight,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: AppTheme.spacingL),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Iconsax.refresh, size: 16),
            label: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}

class _ToolMeta {
  final IconData icon;
  final Color color;
  final String label;

  const _ToolMeta({required this.icon, required this.color, required this.label});
}

_ToolMeta _toolMeta(String tool, String action) {
  switch ('$tool:$action') {
    case 'manage_todos:create':
      return const _ToolMeta(
        icon: Iconsax.task_square,
        color: AppColors.primaryLight,
        label: 'AI 할 일 생성',
      );
    case 'manage_todos:complete':
      return const _ToolMeta(
        icon: Iconsax.tick_circle,
        color: AppColors.successLight,
        label: 'AI 할 일 완료',
      );
    case 'manage_calendar:create':
      return const _ToolMeta(
        icon: Iconsax.calendar_add,
        color: AppColors.primaryLight,
        label: 'AI 일정 생성',
      );
    case 'manage_calendar:update':
      return const _ToolMeta(
        icon: Iconsax.calendar_edit,
        color: AppColors.primaryLight,
        label: 'AI 일정 수정',
      );
    case 'manage_notes:create':
      return const _ToolMeta(
        icon: Iconsax.note_add,
        color: AppColors.chatColor,
        label: 'AI 메모 생성',
      );
    case 'manage_notes:update':
      return const _ToolMeta(
        icon: Iconsax.edit,
        color: AppColors.chatColor,
        label: 'AI 메모 수정',
      );
    case 'create_reminder:create':
      return const _ToolMeta(
        icon: Iconsax.notification,
        color: AppColors.primaryLight,
        label: 'AI 리마인더 생성',
      );
  }
  return _ToolMeta(
    icon: Iconsax.magic_star,
    color: AppColors.primaryLight,
    label: '$tool · $action',
  );
}

String _executionStatusLabel(String status) {
  switch (status) {
    case 'created':
      return '생성됨';
    case 'updated':
      return '수정됨';
    case 'completed':
      return '완료됨';
    case 'cancelled':
      return '취소됨';
    case 'failed':
      return '실패';
    default:
      return status.isNotEmpty ? status : '처리됨';
  }
}

Color _executionStatusColor(String status) {
  switch (status) {
    case 'created':
    case 'updated':
    case 'completed':
      return AppColors.successLight;
    case 'cancelled':
      return AppColors.textSecondaryLight;
    case 'failed':
      return AppColors.errorLight;
    default:
      return AppColors.primaryLight;
  }
}

String _scopeLabel(String scope) {
  switch (scope) {
    case 'personal':
      return '개인';
    case 'shared':
    case 'space':
      return '공유';
    case 'channel':
      return '채널';
    default:
      return scope;
  }
}

String? _formatTimestamp(DateTime? value) {
  if (value == null) return null;
  final now = DateTime.now();
  final diff = now.difference(value);

  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';

  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '$mm월 $dd일';
}
