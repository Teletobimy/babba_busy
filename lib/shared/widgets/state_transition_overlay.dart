import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 상태 전환 시 표시되는 오버레이
/// 그룹 전환, 데이터 로딩 등의 상황에서 부드러운 전환 제공
class StateTransitionOverlay extends StatelessWidget {
  final String? message;
  final bool isVisible;
  final Widget child;
  final Duration duration;

  const StateTransitionOverlay({
    super.key,
    this.message,
    required this.isVisible,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: duration,
          child: isVisible
              ? _TransitionOverlayContent(message: message)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TransitionOverlayContent extends StatelessWidget {
  final String? message;

  const _TransitionOverlayContent({this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
          .withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 그룹 전환 전용 Provider
/// 전환 상태를 추적하여 UI에서 오버레이 표시 가능
class GroupTransitionState {
  final bool isTransitioning;
  final String? targetGroupId;
  final String? targetGroupName;

  const GroupTransitionState({
    this.isTransitioning = false,
    this.targetGroupId,
    this.targetGroupName,
  });

  GroupTransitionState copyWith({
    bool? isTransitioning,
    String? targetGroupId,
    String? targetGroupName,
  }) {
    return GroupTransitionState(
      isTransitioning: isTransitioning ?? this.isTransitioning,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
    );
  }
}
