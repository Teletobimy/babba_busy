import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FCM 토큰 Provider
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final notificationService = ref.read(notificationServiceProvider);
  return notificationService.getToken();
});

/// 알림 서비스 Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// 알림 서비스
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 알림 권한 요청
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// FCM 토큰 가져오기
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// 포그라운드 메시지 핸들러 설정
  void setupForegroundMessageHandler(
    void Function(RemoteMessage message) onMessage,
  ) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// 백그라운드 메시지 탭 핸들러 설정
  void setupBackgroundMessageTapHandler(
    void Function(RemoteMessage message) onMessageTap,
  ) {
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageTap);
  }

  /// 앱이 종료된 상태에서 알림 탭으로 앱 열기
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  /// 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// 가족 토픽 구독 (가족 알림용)
  Future<void> subscribeToFamily(String familyId) async {
    await subscribeToTopic('family_$familyId');
  }

  /// 가족 토픽 구독 해제
  Future<void> unsubscribeFromFamily(String familyId) async {
    await unsubscribeFromTopic('family_$familyId');
  }
}

/// 백그라운드 메시지 핸들러 (main.dart에서 등록 필요)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서 메시지 처리
  // 여기서 로컬 알림 표시 등의 작업 수행 가능
}
