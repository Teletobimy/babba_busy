import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

/// 온보딩 완료 여부 체크
Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_tour_completed') ?? false;
}

/// 온보딩 완료 마킹
Future<void> markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_tour_completed', true);
}

/// 온보딩 투어 오버레이
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentStep = 0;

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      markOnboardingCompleted();
      widget.onComplete();
    }
  }

  void _skip() {
    markOnboardingCompleted();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Stack(
          children: [
            // 전체 탭으로 다음 단계
            GestureDetector(
              onTap: _next,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            // 설명 카드
            Positioned(
              left: 24,
              right: 24,
              top: step.position == OnboardingPosition.top ? 80 : null,
              bottom: step.position == OnboardingPosition.bottom ? 120 : null,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step.icon != null)
                      Icon(step.icon, size: 32, color: AppColors.primaryLight),
                    if (step.icon != null) const SizedBox(height: 12),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 진행도
                        Text(
                          '${_currentStep + 1} / ${widget.steps.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                        Row(
                          children: [
                            if (_currentStep < widget.steps.length - 1)
                              TextButton(
                                onPressed: _skip,
                                child: const Text('건너뛰기'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _next,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 온보딩 단계
class OnboardingStep {
  final String title;
  final String description;
  final IconData? icon;
  final OnboardingPosition position;

  const OnboardingStep({
    required this.title,
    required this.description,
    this.icon,
    this.position = OnboardingPosition.top,
  });
}

enum OnboardingPosition { top, bottom }
