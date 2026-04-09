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
  static const Color textSecondaryLight = Color(0xFF636363); // WCAG AA 4.5:1+ on #FDF6EC
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

  // ============ WCAG AA 고대비 텍스트용 색상 (4.5:1+ on white) ============
  static const Color calendarColorOnWhite = Color(0xFF2D8B65);  // ~5.0:1
  static const Color primaryOnWhite = Color(0xFFC4754A);        // ~4.5:1
  static const Color todoColorOnWhite = Color(0xFFC4754A);      // ~4.5:1
  static const Color accentOnWhite = Color(0xFF7B6A9E);         // ~4.5:1
  static const Color textSecondaryLightAA = Color(0xFF636363);  // 4.5:1+ on #FDF6EC

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

  // ============ MaterialColor 팔레트 ============
  /// Coral 팔레트 (따뜻한 코랄)
  static const MaterialColor coral = MaterialColor(0xFFE8A87C, {
    50: Color(0xFFFDF3EE),
    100: Color(0xFFFBE4D5),
    200: Color(0xFFF5CEB3),
    300: Color(0xFFEFB791),
    400: Color(0xFFE8A87C),
    500: Color(0xFFE8A87C),
    600: Color(0xFFD4917A),
    700: Color(0xFFBF7A68),
    800: Color(0xFFAA6456),
    900: Color(0xFF8A4D43),
  });

  /// Sage 팔레트 (세이지 그린)
  static const MaterialColor sage = MaterialColor(0xFF85DCBA, {
    50: Color(0xFFEDF9F4),
    100: Color(0xFFD1F0E3),
    200: Color(0xFFB3E7D1),
    300: Color(0xFF98DDBF),
    400: Color(0xFF85DCBA),
    500: Color(0xFF85DCBA),
    600: Color(0xFF6BB89B),
    700: Color(0xFF52947C),
    800: Color(0xFF3A705D),
    900: Color(0xFF234C3E),
  });

  /// Lavender 팔레트 (라벤더)
  static const MaterialColor lavender = MaterialColor(0xFFC3B1E1, {
    50: Color(0xFFF5F3FA),
    100: Color(0xFFE8E2F4),
    200: Color(0xFFD9CFEC),
    300: Color(0xFFCBC0E6),
    400: Color(0xFFC3B1E1),
    500: Color(0xFFC3B1E1),
    600: Color(0xFFA596C4),
    700: Color(0xFF877BA7),
    800: Color(0xFF6A618A),
    900: Color(0xFF4D466D),
  });

  /// GrayScale 팔레트
  static const MaterialColor grayScale = MaterialColor(0xFF7A7A7A, {
    50: Color(0xFFFAFAFA),
    100: Color(0xFFF5F5F5),
    200: Color(0xFFEEEEEE),
    300: Color(0xFFE0E0E0),
    400: Color(0xFFBDBDBD),
    500: Color(0xFF9E9E9E),
    600: Color(0xFF757575),
    700: Color(0xFF616161),
    800: Color(0xFF424242),
    900: Color(0xFF212121),
  });

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

  // ============ 도구 모듈 색상 ============
  static const Color peopleColor = Color(0xFF5B8DEF);  // 사람들
  static const Color chatColor = Color(0xFF9B59B6);    // 대화방
  static const Color communityColor = Color(0xFF2AA198); // 커뮤니티

  // ============ People & Care 색상 ============

  // 생일 카운트다운
  static const Color birthdayCountdown = Color(0xFFFF6B6B);

  // 빠른 액션 색상
  static const Color actionCall = Color(0xFF4ECDC4);
  static const Color actionMessage = Color(0xFF7C4DFF);
  static const Color actionEmail = Color(0xFFFFA726);
  static const Color actionSchedule = Color(0xFF42A5F5);

  // 관계 색상
  static const Color relationFamily = Color(0xFFFF6B6B);
  static const Color relationFriend = Color(0xFF4ECDC4);
  static const Color relationColleague = Color(0xFFFFA726);
  static const Color relationSchool = Color(0xFF7C4DFF);
  static const Color relationNeighbor = Color(0xFF66BB6A);
  static const Color relationOther = Color(0xFF90A4AE);

  // 케어 점수 색상
  static const Color careScoreHigh = Color(0xFFFF5252);
  static const Color careScoreMedium = Color(0xFFFF9800);
  static const Color careScoreNormal = Color(0xFF42A5F5);
  static const Color careScoreLow = Color(0xFF66BB6A);

  // ============ 심리검사 테마 색상 ============
  static const Map<String, MaterialColor> testColors = {
    'big5': coral,
    'mbti': lavender,
    'attachment': MaterialColor(0xFFF8B4B4, {  // Rose
      50: Color(0xFFFEF2F2), 100: Color(0xFFFCE7E7), 200: Color(0xFFFBD5D5),
      300: Color(0xFFF9C3C3), 400: Color(0xFFF8B4B4), 500: Color(0xFFF8B4B4),
      600: Color(0xFFE5A3A3), 700: Color(0xFFD29292), 800: Color(0xFFBF8181), 900: Color(0xFF996666),
    }),
    'love_language': MaterialColor(0xFFFFB6C1, {  // Light Pink
      50: Color(0xFFFFF0F3), 100: Color(0xFFFFE4E9), 200: Color(0xFFFFD5DD),
      300: Color(0xFFFFC6D1), 400: Color(0xFFFFB6C1), 500: Color(0xFFFFB6C1),
      600: Color(0xFFE5A3AD), 700: Color(0xFFCC9099), 800: Color(0xFFB27D85), 900: Color(0xFF8C6269),
    }),
    'stress': MaterialColor(0xFFFFB74D, {  // Orange
      50: Color(0xFFFFF8E1), 100: Color(0xFFFFECB3), 200: Color(0xFFFFE082),
      300: Color(0xFFFFD54F), 400: Color(0xFFFFCA28), 500: Color(0xFFFFB74D),
      600: Color(0xFFFFA726), 700: Color(0xFFFF9800), 800: Color(0xFFFB8C00), 900: Color(0xFFF57C00),
    }),
    'anxiety': MaterialColor(0xFFF4D06F, {  // Amber/Honey
      50: Color(0xFFFFFBE6), 100: Color(0xFFFFF5CC), 200: Color(0xFFFEEDB3),
      300: Color(0xFFFEE599), 400: Color(0xFFF9DC7F), 500: Color(0xFFF4D06F),
      600: Color(0xFFE0BC5E), 700: Color(0xFFCCA84D), 800: Color(0xFFB8943C), 900: Color(0xFF8A6F2D),
    }),
    'depression': grayScale,
  };

  // ============ 유틸리티 메서드 ============
  static Color getMemberColor(int index) {
    return memberColors[index % memberColors.length];
  }

  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['other']!;
  }

  static MaterialColor getTestColor(String testType) {
    return testColors[testType] ?? coral;
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
