import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ai/ai_api_service.dart';
import '../../../shared/providers/user_brain_provider.dart';
import '../../../shared/widgets/app_card.dart';

/// 홈 화면에 노출할 proactive AI suggestion 카드.
///
/// 동작:
///  - 진입 시 [userBrainInitialReflectProvider]로 reflection 1회 실행
///  - 첫 suggestion 1건만 카드로 표시
///  - 화면 노출 즉시 'shown' stamp
///  - 동의 버튼 → 'accepted' stamp + (TODO: action_payload 기반 후속 처리)
///  - 거절 버튼 → 'dismissed' stamp + suggestion 숨김
class ProactiveSuggestionCard extends ConsumerStatefulWidget {
  const ProactiveSuggestionCard({super.key});

  @override
  ConsumerState<ProactiveSuggestionCard> createState() =>
      _ProactiveSuggestionCardState();
}

class _ProactiveSuggestionCardState
    extends ConsumerState<ProactiveSuggestionCard> {
  final Set<String> _stampedShown = {};
  final Set<String> _hiddenIds = {};
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    // 첫 진입 시 reflect 트리거 (응답 안 기다리고 watch만 — suggestions provider가 결과 받음)
    ref.watch(userBrainInitialReflectProvider);

    final asyncSuggestions = ref.watch(userBrainSuggestionsProvider);

    return asyncSuggestions.when(
      loading: () => const SizedBox.shrink(),  // 로딩은 조용히 (홈 가뜩 차있음)
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        // 미dismiss + shown 안 된 또는 dismissed/accepted 아닌 첫 항목
        UserBrainSuggestion? target;
        for (final s in result.items) {
          if (_hiddenIds.contains(s.suggestionId)) continue;
          // 이미 결정된 (accepted=true 또는 false=dismissed) suggestion 제외
          if (s.accepted != null) continue;
          target = s;
          break;
        }
        if (target == null) return const SizedBox.shrink();

        // shown stamp (1회만)
        if (!_stampedShown.contains(target.suggestionId) &&
            target.stages.shown == null) {
          _stampedShown.add(target.suggestionId);
          // fire-and-forget: 사용자에게 latency 영향 없게
          unawaited(
            ref.read(aiApiServiceProvider).stampUserBrainSuggestion(
                  suggestionId: target.suggestionId,
                  stage: 'shown',
                ),
          );
        }

        return _SuggestionTile(
          suggestion: target,
          onAccept: _processing ? null : () => _onAccept(target!),
          onDismiss: _processing ? null : () => _onDismiss(target!),
        );
      },
    );
  }

  Future<void> _onAccept(UserBrainSuggestion s) async {
    setState(() => _processing = true);
    try {
      await ref.read(aiApiServiceProvider).stampUserBrainSuggestion(
            suggestionId: s.suggestionId,
            stage: 'accepted',
          );
      if (!mounted) return;
      setState(() => _hiddenIds.add(s.suggestionId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI 제안을 수락했어요. 후속 작업은 곧 도착해요 😊'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _onDismiss(UserBrainSuggestion s) async {
    setState(() => _processing = true);
    try {
      await ref.read(aiApiServiceProvider).stampUserBrainSuggestion(
            suggestionId: s.suggestionId,
            stage: 'dismissed',
          );
      if (!mounted) return;
      setState(() => _hiddenIds.add(s.suggestionId));
    } catch (_) {
      // dismiss 실패는 silent — 다음 새로고침에 다시 보여도 OK
      if (!mounted) return;
      setState(() => _hiddenIds.add(s.suggestionId));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _SuggestionTile extends StatelessWidget {
  final UserBrainSuggestion suggestion;
  final VoidCallback? onAccept;
  final VoidCallback? onDismiss;

  const _SuggestionTile({
    required this.suggestion,
    this.onAccept,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final meta = _meta(suggestion.type);

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
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 18, color: meta.color),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'AI 제안',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: meta.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    if (suggestion.body != null &&
                        suggestion.body!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        suggestion.body!.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: mutedColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('지금 안 함'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: meta.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  icon: const Icon(Iconsax.shield_tick, size: 16),
                  label: const Text('동의', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta {
  final IconData icon;
  final Color color;
  const _Meta(this.icon, this.color);
}

_Meta _meta(String type) {
  switch (type) {
    case 'reminder_setup':
      return const _Meta(Iconsax.notification, AppColors.primaryLight);
    case 'encouragement':
      return const _Meta(Iconsax.heart, AppColors.successLight);
    case 'event_prep':
      return const _Meta(Iconsax.note_add, AppColors.chatColor);
  }
  return const _Meta(Iconsax.magic_star, AppColors.primaryLight);
}

/// fire-and-forget helper (await 안 함)
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
