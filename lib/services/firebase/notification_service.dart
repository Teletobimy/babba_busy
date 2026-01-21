import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

/// 알림 채널 ID 상수
class NotificationChannelId {
  static const String defaultChannel = 'babba_default_channel';
  static const String chatChannel = 'babba_chat_channel';
  static const String todoChannel = 'babba_todo_channel';
  static const String eventChannel = 'babba_event_channel';
}

/// 알림 서비스
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// 앱 시작 시 알림 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 로컬 알림 플러그인 초기화
    await _initializeLocalNotifications();

    // Android 알림 채널 생성
    await _createNotificationChannels();

    // 포그라운드 메시지 핸들러 설정
    _setupForegroundMessageHandler();

    // 메시지 탭 핸들러 설정
    _setupMessageTapHandler();

    // 토큰 갱신 리스너 설정
    _setupTokenRefreshListener();

    _isInitialized = true;
    debugPrint('NotificationService 초기화 완료');
  }

  /// 로컬 알림 플러그인 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // 기본 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.defaultChannel,
        'BABBA 알림',
        description: 'BABBA 앱 알림',
        importance: Importance.high,
      ),
    );

    // 채팅 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.chatChannel,
        '채팅 알림',
        description: '새 채팅 메시지 알림',
        importance: Importance.high,
      ),
    );

    // 할일 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.todoChannel,
        '할일 알림',
        description: '할일 관련 알림',
        importance: Importance.defaultImportance,
      ),
    );

    // 일정 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.eventChannel,
        '일정 알림',
        description: '일정 관련 알림',
        importance: Importance.high,
      ),
    );
  }

  /// 포그라운드 메시지 핸들러 설정
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// 포그라운드 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('포그라운드 메시지 수신: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // 알림 타입에 따른 채널 선택
    final channelId = _getChannelId(message.data['type']);

    await _showLocalNotification(
      title: notification.title ?? 'BABBA',
      body: notification.body ?? '',
      channelId: channelId,
      payload: message.data.toString(),
    );
  }

  /// 알림 타입에 따른 채널 ID 반환
  String _getChannelId(String? type) {
    switch (type) {
      case 'chat':
        return NotificationChannelId.chatChannel;
      case 'todo':
        return NotificationChannelId.todoChannel;
      case 'event':
        return NotificationChannelId.eventChannel;
      default:
        return NotificationChannelId.defaultChannel;
    }
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 채널 ID로 채널 이름 반환
  String _getChannelName(String channelId) {
    switch (channelId) {
      case NotificationChannelId.chatChannel:
        return '채팅 알림';
      case NotificationChannelId.todoChannel:
        return '할일 알림';
      case NotificationChannelId.eventChannel:
        return '일정 알림';
      default:
        return 'BABBA 알림';
    }
  }

  /// 알림 탭 핸들러
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('알림 탭: ${response.payload}');
    // TODO: 알림 탭 시 해당 화면으로 네비게이션
  }

  /// 메시지 탭 핸들러 설정
  void _setupMessageTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('백그라운드 알림 탭: ${message.messageId}');
      // TODO: 알림 탭 시 해당 화면으로 네비게이션
    });
  }

  /// 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM 토큰 갱신: $newToken');
      // 토큰 저장은 앱에서 userId가 있을 때 처리
    });
  }

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

  /// FCM 토큰 Firestore에 저장
  Future<void> saveTokenToFirestore(String userId) async {
    final token = await getToken();
    if (token == null) return;

    final userRef = _firestore.collection('users').doc(userId);

    // 토큰 배열에 추가 (중복 방지)
    await userRef.update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });

    debugPrint('FCM 토큰 저장 완료: $userId');
  }

  /// FCM 토큰 Firestore에서 제거 (로그아웃 시)
  Future<void> removeTokenFromFirestore(String userId) async {
    final token = await getToken();
    if (token == null) return;

    final userRef = _firestore.collection('users').doc(userId);

    // 토큰 배열에서 제거
    await userRef.update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });

    debugPrint('FCM 토큰 제거 완료: $userId');
  }

  /// 앱이 종료된 상태에서 알림 탭으로 앱 열기
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  /// 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('토픽 구독: $topic');
  }

  /// 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('토픽 구독 해제: $topic');
  }

  /// 가족 토픽 구독 (가족 알림용)
  Future<void> subscribeToFamily(String familyId) async {
    await subscribeToTopic('family_$familyId');
  }

  /// 가족 토픽 구독 해제
  Future<void> unsubscribeFromFamily(String familyId) async {
    await unsubscribeFromTopic('family_$familyId');
  }

  /// 모든 그룹 토픽 구독 해제
  Future<void> unsubscribeFromAllFamilies(List<String> familyIds) async {
    for (final familyId in familyIds) {
      await unsubscribeFromFamily(familyId);
    }
  }
}

/// 백그라운드 메시지 핸들러 (main.dart에서 등록 필요)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 메시지 수신: ${message.messageId}');
  // 백그라운드에서는 시스템이 자동으로 알림 표시
  // 추가 데이터 처리가 필요한 경우 여기서 수행
}
