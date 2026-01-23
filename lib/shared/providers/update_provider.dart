import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/app_update_service.dart';

/// 앱 업데이트 정보 Provider
/// 앱 시작 시 한 번 체크하고 결과를 캐싱
final appUpdateProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  return await AppUpdateService.checkForUpdate();
});

/// 업데이트 강제 체크 (설정 화면 등에서 수동 체크용)
final forceUpdateCheckProvider = FutureProvider.family<AppUpdateInfo?, bool>((ref, force) async {
  return await AppUpdateService.checkForUpdate(force: force);
});
