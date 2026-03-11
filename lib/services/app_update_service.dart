import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 업데이트 정보
class AppUpdateInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String remoteVersion;
  final int remoteBuildNumber;
  final DateTime? remoteBuildTime;
  final bool updateAvailable;

  AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.remoteVersion,
    required this.remoteBuildNumber,
    this.remoteBuildTime,
    required this.updateAvailable,
  });
}

/// 앱 업데이트 체크 서비스
class AppUpdateService {
  static const String _versionJsonUrl =
      String.fromEnvironment('VERSION_JSON_URL');
  static const String _skipVersionKey = 'skip_update_version';
  static const String _lastCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 6);

  /// 업데이트 체크 (캐싱 적용)
  static Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      // 웹에서는 업데이트 체크 불필요 (자동 새로고침)
      if (kIsWeb) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();

      // 강제 체크가 아니면 간격 확인
      if (!force) {
        final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastCheck < _checkInterval.inMilliseconds) {
          return null;
        }
      }

      // 현재 앱 버전 정보
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 원격 버전 정보 가져오기
      final response = await http
          .get(Uri.parse(_versionJsonUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final remoteData = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuildNumber = remoteData['buildNumber'] as int? ?? 0;
      final remoteVersion = remoteData['version'] as String? ?? '';
      final remoteBuildTimeStr = remoteData['buildTime'] as String?;

      DateTime? remoteBuildTime;
      if (remoteBuildTimeStr != null) {
        remoteBuildTime = DateTime.tryParse(remoteBuildTimeStr);
      }

      // 마지막 체크 시간 저장
      await prefs.setInt(
          _lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      final updateAvailable = remoteBuildNumber > currentBuildNumber;

      return AppUpdateInfo(
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuildNumber,
        remoteVersion: remoteVersion,
        remoteBuildNumber: remoteBuildNumber,
        remoteBuildTime: remoteBuildTime,
        updateAvailable: updateAvailable,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  /// 특정 버전 업데이트 스킵
  static Future<void> skipVersion(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipVersionKey, buildNumber);
  }

  /// 스킵된 버전인지 확인
  static Future<bool> isVersionSkipped(int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final skippedVersion = prefs.getInt(_skipVersionKey) ?? 0;
    return buildNumber <= skippedVersion;
  }

  /// 스킵 버전 초기화
  static Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skipVersionKey);
  }
}
