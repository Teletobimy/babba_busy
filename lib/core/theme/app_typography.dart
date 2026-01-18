import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 앱 타이포그래피 시스템
/// Nunito - 헤드라인 (둥글고 친근한 느낌)
/// Noto Sans KR - 본문 (한글 가독성)
class AppTypography {
  AppTypography._();

  // ============ 폰트 패밀리 ============
  static String get headlineFont => GoogleFonts.nunito().fontFamily!;
  static String get bodyFont => GoogleFonts.notoSansKr().fontFamily!;

  // ============ 라이트 모드 텍스트 스타일 ============
  static TextTheme get lightTextTheme => TextTheme(
    // Display
    displayLarge: GoogleFonts.nunito(
      fontSize: 57,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.nunito(
      fontSize: 45,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),
    displaySmall: GoogleFonts.nunito(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),

    // Headline
    headlineLarge: GoogleFonts.nunito(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    headlineMedium: GoogleFonts.nunito(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
    ),
    headlineSmall: GoogleFonts.nunito(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
    ),

    // Title
    titleLarge: GoogleFonts.notoSansKr(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
    ),
    titleMedium: GoogleFonts.notoSansKr(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.15,
    ),
    titleSmall: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.1,
    ),

    // Body
    bodyLarge: GoogleFonts.notoSansKr(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.5,
    ),
    bodyMedium: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.notoSansKr(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryLight,
      letterSpacing: 0.4,
    ),

    // Label
    labelLarge: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.notoSansKr(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryLight,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.notoSansKr(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryLight,
      letterSpacing: 0.5,
    ),
  );

  // ============ 다크 모드 텍스트 스타일 ============
  static TextTheme get darkTextTheme => TextTheme(
    // Display
    displayLarge: GoogleFonts.nunito(
      fontSize: 57,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryDark,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.nunito(
      fontSize: 45,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryDark,
    ),
    displaySmall: GoogleFonts.nunito(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryDark,
    ),

    // Headline
    headlineLarge: GoogleFonts.nunito(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    headlineMedium: GoogleFonts.nunito(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
    ),
    headlineSmall: GoogleFonts.nunito(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
    ),

    // Title
    titleLarge: GoogleFonts.notoSansKr(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
    ),
    titleMedium: GoogleFonts.notoSansKr(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.15,
    ),
    titleSmall: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.1,
    ),

    // Body
    bodyLarge: GoogleFonts.notoSansKr(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.5,
    ),
    bodyMedium: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.notoSansKr(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryDark,
      letterSpacing: 0.4,
    ),

    // Label
    labelLarge: GoogleFonts.notoSansKr(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.notoSansKr(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryDark,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.notoSansKr(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondaryDark,
      letterSpacing: 0.5,
    ),
  );
}
