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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: AppColors.coral,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // 제목
            const Text(
              '새 버전이 있어요!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 버전 정보
            Text(
              '${updateInfo.currentVersion} → ${updateInfo.remoteVersion}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // 업데이트 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => _launchUpdate(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '업데이트',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 나중에 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onLater,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '나중에',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 건너뛰기
            TextButton(
              onPressed: onSkip,
              child: Text(
                '이 버전 건너뛰기',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpdate(BuildContext context) async {
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
