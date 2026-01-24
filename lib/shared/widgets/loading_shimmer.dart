import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 로딩 상태를 위한 Shimmer 효과 위젯
/// 일관된 로딩 UI를 제공
class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppTheme.radiusSmall,
    this.margin,
  });

  /// 텍스트 라인 shimmer
  factory LoadingShimmer.text({
    double width = 100,
    double height = 16,
    EdgeInsetsGeometry? margin,
  }) {
    return LoadingShimmer(
      width: width,
      height: height,
      borderRadius: 4,
      margin: margin,
    );
  }

  /// 원형 shimmer (아바타용)
  factory LoadingShimmer.circle({
    double size = 40,
    EdgeInsetsGeometry? margin,
  }) {
    return LoadingShimmer(
      width: size,
      height: size,
      borderRadius: size / 2,
      margin: margin,
    );
  }

  /// 카드 shimmer
  factory LoadingShimmer.card({
    double height = 80,
    EdgeInsetsGeometry? margin,
  }) {
    return LoadingShimmer(
      width: double.infinity,
      height: height,
      borderRadius: AppTheme.radiusMedium,
      margin: margin,
    );
  }

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.surfaceDark
        : Colors.grey[300]!;
    final highlightColor = isDark
        ? AppColors.backgroundDark
        : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 할일 카드 로딩 shimmer
class TodoCardShimmer extends StatelessWidget {
  const TodoCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          LoadingShimmer.circle(size: 24),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmer.text(width: 150),
                const SizedBox(height: AppTheme.spacingXS),
                LoadingShimmer.text(width: 80, height: 12),
              ],
            ),
          ),
          LoadingShimmer.circle(size: 32),
        ],
      ),
    );
  }
}

/// 홈 화면 로딩 상태
class HomeScreenShimmer extends StatelessWidget {
  const HomeScreenShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 shimmer
          Row(
            children: [
              LoadingShimmer.circle(size: 48),
              const Spacer(),
              LoadingShimmer(width: 100, height: 36, borderRadius: AppTheme.radiusSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          LoadingShimmer.text(width: 120, height: 20),
          const SizedBox(height: AppTheme.spacingXS),
          LoadingShimmer.text(width: 180, height: 28),
          const SizedBox(height: AppTheme.spacingXL),

          // AI 요약 카드 shimmer
          LoadingShimmer.card(height: 100),
          const SizedBox(height: AppTheme.spacingL),

          // 멤버 필터 shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LoadingShimmer.circle(size: 40),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 할일 리스트 shimmer
          LoadingShimmer.text(width: 100, height: 20),
          const SizedBox(height: AppTheme.spacingM),
          const TodoCardShimmer(),
          const TodoCardShimmer(),
          const TodoCardShimmer(),
        ],
      ),
    );
  }
}

/// 캘린더 화면 로딩 상태
class CalendarScreenShimmer extends StatelessWidget {
  const CalendarScreenShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LoadingShimmer.text(width: 80, height: 28),
              Row(
                children: [
                  LoadingShimmer.circle(size: 40),
                  const SizedBox(width: AppTheme.spacingS),
                  LoadingShimmer.circle(size: 40),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 멤버 필터 shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LoadingShimmer.circle(size: 40),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 캘린더 shimmer
          LoadingShimmer.card(height: 350),
        ],
      ),
    );
  }
}
