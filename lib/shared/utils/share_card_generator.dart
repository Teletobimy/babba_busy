import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 카드 생성 유틸리티
class ShareCardGenerator {
  /// 위젯을 이미지로 변환하여 공유
  static Future<void> shareWidget({
    required GlobalKey repaintKey,
    required String shareText,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/babba_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }
}

/// 스트릭 공유 카드 위젯
class StreakShareCard extends StatelessWidget {
  final int streak;
  final int completedToday;

  const StreakShareCard({
    super.key,
    required this.streak,
    required this.completedToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🔥',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          Text(
            '$streak일 연속 달성!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 $completedToday개 완료',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'BABBA - 바쁜 일상 관리',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 주간 통계 공유 카드 위젯
class WeeklyStatsShareCard extends StatelessWidget {
  final int totalCompleted;
  final String bestDay;
  final double avgPerDay;

  const WeeklyStatsShareCard({
    super.key,
    required this.totalCompleted,
    required this.bestDay,
    required this.avgPerDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '📊',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          const Text(
            '이번 주 리포트',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(label: '완료', value: '$totalCompleted개'),
              _StatItem(label: '일 평균', value: avgPerDay.toStringAsFixed(1)),
              _StatItem(label: '최고 요일', value: bestDay),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'BABBA - 바쁜 일상 관리',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
