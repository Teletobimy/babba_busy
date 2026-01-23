import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_settings.dart';
import 'auth_provider.dart';
import '../../services/firebase/notification_service.dart';

/// 알림 설정 Provider - 현재 사용자의 알림 설정을 Firestore에서 스트림으로 가져옴
final notificationSettingsProvider =
    StreamProvider<NotificationSettings>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const NotificationSettings());
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return const NotificationSettings();
    final data = doc.data();
    return NotificationSettings.fromMap(
      data?['notificationSettings'] as Map<String, dynamic>?,
    );
  });
});

/// 알림 설정 서비스 Provider
final notificationSettingsServiceProvider =
    Provider<NotificationSettingsService>((ref) {
  return NotificationSettingsService(ref);
});

/// 알림 설정 서비스 - Firestore 업데이트 담당
class NotificationSettingsService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NotificationSettingsService(this._ref);

  /// 알림 설정 업데이트
  Future<void> updateSettings(NotificationSettings settings) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'notificationSettings': settings.toMap(),
      });
      debugPrint('알림 설정 업데이트 완료');
    } catch (e) {
      debugPrint('알림 설정 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 전체 알림 on/off 토글
  Future<void> toggleEnabled(bool enabled) async {
    final currentSettings = _ref.read(notificationSettingsProvider).valueOrNull;
    if (currentSettings == null) return;

    await updateSettings(currentSettings.copyWith(enabled: enabled));
  }

  /// 채팅 알림 토글
  Future<void> toggleChat(bool enabled) async {
    final currentSettings = _ref.read(notificationSettingsProvider).valueOrNull;
    if (currentSettings == null) return;

    await updateSettings(currentSettings.copyWith(chatEnabled: enabled));
  }

  /// 할일 알림 토글
  Future<void> toggleTodo(bool enabled) async {
    final currentSettings = _ref.read(notificationSettingsProvider).valueOrNull;
    if (currentSettings == null) return;

    await updateSettings(currentSettings.copyWith(todoEnabled: enabled));
  }

  /// 일정 알림 토글
  Future<void> toggleEvent(bool enabled) async {
    final currentSettings = _ref.read(notificationSettingsProvider).valueOrNull;
    if (currentSettings == null) return;

    await updateSettings(currentSettings.copyWith(eventEnabled: enabled));
  }
}

/// FCM 토큰 저장 Provider - 로그인 시 토큰 저장
/// autoDispose 제거: 토큰 저장 완료 전 dispose 방지
final fcmTokenSaverProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final notificationService = ref.read(notificationServiceProvider);

  try {
    debugPrint('🔔 FCM 초기화 시작: ${user.uid}');

    // 1. 알림 권한 요청
    final hasPermission = await notificationService.requestPermission();
    if (!hasPermission) {
      debugPrint('⚠️ 사용자가 알림 권한을 거부했습니다');
      return;
    }

    debugPrint('✅ 알림 권한 획득');

    // 2. 알림 서비스 초기화
    await notificationService.initialize();

    // 3. FCM 토큰 저장
    await notificationService.saveTokenToFirestore(user.uid);

    debugPrint('✅ FCM 토큰 저장 완료: ${user.uid}');
  } catch (e, stack) {
    debugPrint('❌ FCM 토큰 저장 중 에러: $e');
    debugPrint('Stack trace: $stack');
    // 에러를 throw하지 않고 로그만 남김 (로그인은 계속 진행되어야 함)
  }
});
