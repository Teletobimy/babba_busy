import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 앱 초기 로딩 시 표시되는 오버레이
/// 데이터 로드 중 깜빡임을 방지합니다
/// 로고만 표시하여 자연스러운 전환 제공
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로고
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.family_restroom,
                size: 40,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 16),
            // 앱 이름
            Text(
              'BABBA',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
