import 'package:flutter/material.dart';

/// 앱 색상 시스템
/// 따뜻하고 포근한 파스텔톤 팔레트
class AppColors {
  AppColors._();

  // ============ 라이트 모드 ============
  static const Color primaryLight = Color(0xFFE8A87C);      // Warm Coral
  static const Color secondaryLight = Color(0xFF85DCBA);    // Sage Green
  static const Color accentLight = Color(0xFFC3B1E1);       // Soft Lavender
  static const Color backgroundLight = Color(0xFFFDF6EC);   // Warm Cream
  static const Color surfaceLight = Color(0xFFFFFFFF);      // White
  static const Color textPrimaryLight = Color(0xFF3D3D3D);  // Warm Charcoal
  static const Color textSecondaryLight = Color(0xFF7A7A7A); // Muted Gray
  static const Color errorLight = Color(0xFFE57373);
  static const Color successLight = Color(0xFF81C784);

  // ============ 다크 모드 ============
  static const Color primaryDark = Color(0xFFD4917A);       // Muted Coral
  static const Color secondaryDark = Color(0xFF6BB89B);     // Deep Sage
  static const Color accentDark = Color(0xFFA596C4);        // Dusty Lavender
  static const Color backgroundDark = Color(0xFF1E1D1D);    // Warm Dark
  static const Color surfaceDark = Color(0xFF2A2929);       // Soft Dark
  static const Color textPrimaryDark = Color(0xFFF5F0E8);   // Warm White
  static const Color textSecondaryDark = Color(0xFFB0A99F); // Muted Light
  static const Color errorDark = Color(0xFFEF9A9A);
  static const Color successDark = Color(0xFFA5D6A7);

  // ============ 기능별 테마 색상 ============
  static const Color todoColor = Color(0xFFE8A87C);         // Coral - 따뜻한 활력
  static const Color calendarColor = Color(0xFF85DCBA);     // Sage - 차분한 계획
  static const Color memoryColor = Color(0xFFC3B1E1);       // Lavender - 감성적 추억
  static const Color budgetColor = Color(0xFFF4D06F);       // Honey - 안정적 재정
  static const Color memoColor = Color(0xFF7986CB);         // Indigo - 깊이있는 기록

  // ============ 구성원 색상 (6인 기준) ============
  static const List<Color> memberColors = [
    Color(0xFFFFCBA4), // Peach
    Color(0xFF98D8C8), // Mint
    Color(0xFFC9B1FF), // Lilac
    Color(0xFF9AD0EC), // Sky Blue
    Color(0xFFF8B4B4), // Rose
    Color(0xFFF4D06F), // Honey
  ];

  static const List<String> memberColorNames = [
    'Peach',
    'Mint',
    'Lilac',
    'Sky',
    'Rose',
    'Honey',
  ];

  // ============ 카테고리 색상 (가계부용) ============
  static const Map<String, Color> categoryColors = {
    'food': Color(0xFFFFB74D),       // 식비 - Orange
    'transport': Color(0xFF4FC3F7),  // 교통 - Blue
    'shopping': Color(0xFFE57373),   // 쇼핑 - Red
    'entertainment': Color(0xFFBA68C8), // 여가 - Purple
    'health': Color(0xFF81C784),     // 건강 - Green
    'education': Color(0xFF64B5F6),  // 교육 - Light Blue
    'housing': Color(0xFF90A4AE),    // 주거 - Gray
    'utilities': Color(0xFFA1887F),  // 공과금 - Brown
    'income': Color(0xFF4CAF50),     // 수입 - Green
    'other': Color(0xFFBDBDBD),      // 기타 - Gray
  };

  // ============ 그라디언트 ============
  static const LinearGradient primaryGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8A87C), Color(0xFFF4D06F)],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4917A), Color(0xFFD4B06F)],
  );

  // ============ 유틸리티 메서드 ============
  static Color getMemberColor(int index) {
    return memberColors[index % memberColors.length];
  }

  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['other']!;
  }
}

/// 라이트/다크 모드에 따른 색상 Extension
extension AppColorsExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get primaryColor => isDarkMode ? AppColors.primaryDark : AppColors.primaryLight;
  Color get secondaryColor => isDarkMode ? AppColors.secondaryDark : AppColors.secondaryLight;
  Color get accentColor => isDarkMode ? AppColors.accentDark : AppColors.accentLight;
  Color get backgroundColor => isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get surfaceColor => isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get textPrimaryColor => isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondaryColor => isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
}
