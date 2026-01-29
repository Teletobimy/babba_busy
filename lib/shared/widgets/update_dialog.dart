import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_update_service.dart';
import '../../core/theme/app_colors.dart';

/// 앱 업데이트 다이얼로그
class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onSkip;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onSkip,
    this.onLater,
  });

  /// 업데이트 다이얼로그 표시
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    // 이미 스킵한 버전이면 표시하지 않음
    if (await AppUpdateService.isVersionSkipped(updateInfo.remoteBuildNumber)) {
      return;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        onSkip: () async {
          await AppUpdateService.skipVersion(updateInfo.remoteBuildNumber);
          if (context.mounted) Navigator.of(context).pop();
        },
        onLater: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: AppColors.coral,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '새 버전 알림',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '더 나은 BABBA가 준비되었어요!',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildVersionRow(
                  '현재 버전',
                  updateInfo.currentVersion,
                  Colors.grey[600]!,
                ),
                const SizedBox(height: 8),
                _buildVersionRow(
                  '최신 버전',
                  updateInfo.remoteVersion,
                  AppColors.coral,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '최신 버전으로 업데이트하면\n새로운 기능과 개선사항을 경험할 수 있어요.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // 버튼들을 세로로 배치
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _launchUpdate(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('업데이트'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  '건너뛰기',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: onLater,
                child: Text(
                  '나중에',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionRow(String label, String version, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          version,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _launchUpdate(BuildContext context) async {
    // PWA는 새로고침으로 업데이트
    const webUrl = 'https://***REMOVED_WEB_DOMAIN***';

    final uri = Uri.parse(webUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
