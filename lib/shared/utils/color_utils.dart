import 'package:flutter/material.dart';

/// 16진수 색상 문자열을 Color 객체로 변환
/// 예: '#FF5733' 또는 'FF5733' → Color(0xFFFF5733)
Color parseHexColor(String? colorHex, {Color fallback = Colors.grey}) {
  if (colorHex == null || colorHex.isEmpty) return fallback;
  try {
    String hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  } catch (e) {
    return fallback;
  }
}
