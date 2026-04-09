import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

// ============ SharedPreferences 키 ============
const _kOnboardingTourCompleted = 'onboarding_tour_completed';

// ============ Riverpod Provider ============

/// 온보딩 투어 완료 여부 Provider (SharedPreferences 기반)
final onboardingTourCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingTourCompleted) ?? false;
});

/// 온보딩 투어 완료 마킹 후 provider 무효화
Future<void> markOnboardingTourCompleted(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingTourCompleted, true);
  ref.invalidate(onboardingTourCompletedProvider);
}

// ============ 데이터 모델 ============

/// 온보딩 투어의 한 단계
class OnboardingStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final Alignment tooltipAlignment;
  final IconData? icon;

  const OnboardingStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.tooltipAlignment = Alignment.bottomCenter,
    this.icon,
  });
}

// ============ 위젯 ============

/// GlobalKey 기반 하이라이트 + 툴팁 온보딩 오버레이
///
/// [child] 위에 반투명 마스크를 깔고, [steps]에 지정된
/// GlobalKey 위젯 영역을 구멍(cutout)으로 뚫어 강조합니다.
class OnboardingOverlay extends StatefulWidget {
  final Widget child;
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;

  const OnboardingOverlay({
    super.key,
    required this.child,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Rect? _targetRect;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    // 첫 프레임 이후 타겟 위치 측정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 현재 step의 GlobalKey로부터 화면 내 Rect를 계산
  void _updateTargetRect() {
    final key = widget.steps[_currentStep].targetKey;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      setState(() {
        _targetRect = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          renderBox.size.width,
          renderBox.size.height,
        );
      });
    } else {
      // 위젯이 아직 레이아웃되지 않은 경우 fallback
      setState(() => _targetRect = null);
    }
  }

  void _goToStep(int step) {
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentStep = step);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTargetRect();
        _animController.forward();
      });
    });
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  void _finish() {
    _animController.reverse().then((_) {
      if (!mounted) return;
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 아래 콘텐츠
        widget.child,
        // 오버레이 (애니메이션)
        FadeTransition(
          opacity: _fadeAnim,
          child: _buildOverlay(context),
        ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final step = widget.steps[_currentStep];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // 패딩이 적용된 하이라이트 영역
    final highlightRect = _targetRect != null
        ? Rect.fromLTRB(
            _targetRect!.left - 8,
            _targetRect!.top - 8,
            _targetRect!.right + 8,
            _targetRect!.bottom + 8,
          )
        : null;

    return Stack(
      children: [
        // 반투명 마스크 + 구멍
        Positioned.fill(
          child: GestureDetector(
            onTap: _next,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _CutoutMaskPainter(
                cutoutRect: highlightRect,
                overlayColor: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),

        // 툴팁 카드
        _buildTooltipCard(
          context,
          step: step,
          isDark: isDark,
          screenSize: screenSize,
          highlightRect: highlightRect,
        ),
      ],
    );
  }

  Widget _buildTooltipCard(
    BuildContext context, {
    required OnboardingStep step,
    required bool isDark,
    required Size screenSize,
    Rect? highlightRect,
  }) {
    // 툴팁 위치 계산
    final double top;
    const double left = 24;
    const double right = 24;

    if (highlightRect == null) {
      // fallback: 화면 중앙
      top = screenSize.height * 0.35;
    } else if (step.tooltipAlignment == Alignment.topCenter) {
      // 타겟 위에 표시
      top = (highlightRect.top - 180).clamp(
        MediaQuery.of(context).padding.top + 16,
        screenSize.height - 250,
      );
    } else {
      // 타겟 아래에 표시 (기본)
      top = (highlightRect.bottom + 16).clamp(
        MediaQuery.of(context).padding.top + 16,
        screenSize.height - 250,
      );
    }

    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘 + 제목
              Row(
                children: [
                  if (step.icon != null) ...[
                    Icon(
                      step.icon,
                      size: 24,
                      color: isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 설명
              Text(
                step.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              // 하단: 스텝 인디케이터 + 버튼
              Row(
                children: [
                  // 스텝 점
                  ...List.generate(widget.steps.length, (i) {
                    final isActive = i == _currentStep;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight)
                            : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                .withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                    );
                  }),
                  const Spacer(),
                  // 건너뛰기
                  if (_currentStep < widget.steps.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('건너뛰기'),
                    ),
                  const SizedBox(width: 4),
                  // 다음 / 시작하기
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.primaryDark
                          : AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                    ),
                    child: Text(
                      _currentStep == widget.steps.length - 1
                          ? '시작하기'
                          : '다음',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ CustomPainter: 반투명 마스크 + RRect 구멍 ============

class _CutoutMaskPainter extends CustomPainter {
  final Rect? cutoutRect;
  final Color overlayColor;

  _CutoutMaskPainter({
    required this.cutoutRect,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    if (cutoutRect == null) {
      // 구멍 없이 전체 덮기
      canvas.drawRect(fullRect, Paint()..color = overlayColor);
      return;
    }

    // 둥근 모서리 구멍
    final cutoutRRect = RRect.fromRectAndRadius(
      cutoutRect!,
      const Radius.circular(12),
    );

    // Path: 전체 화면 - 구멍
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = overlayColor);

    // 구멍 주변 글로우 테두리
    canvas.drawRRect(
      cutoutRRect,
      Paint()
        ..color = AppColors.primaryLight.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CutoutMaskPainter oldDelegate) {
    return cutoutRect != oldDelegate.cutoutRect ||
        overlayColor != oldDelegate.overlayColor;
  }
}
