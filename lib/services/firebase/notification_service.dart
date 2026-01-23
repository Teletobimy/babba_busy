import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  static const String businessChannel = 'babba_business_channel';
  static const String analysisChannel = 'babba_analysis_channel';
}

/// 알림 서비스 (싱글톤)
class NotificationService {
  // 싱글톤 인스턴스
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;
  String? _currentUserId;

  /// 현재 사용자 ID 설정 (토큰 갱신 시 자동 저장용)
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    debugPrint('📱 NotificationService userId 설정: $userId');
  }

  /// Navigator Key 설정
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

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
    // 웹이거나 Android가 아니면 스킵
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

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

    // 사업 검토 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.businessChannel,
        '사업 검토 알림',
        description: '사업 검토 결과 알림',
        importance: Importance.high,
      ),
    );

    // 분석 작업 채널
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannelId.analysisChannel,
        '분석 결과 알림',
        description: 'AI 분석 결과 알림',
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
      payload: jsonEncode(message.data),
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
      case 'business_review':
        return NotificationChannelId.businessChannel;
      case 'analysis_complete':
      case 'analysis_failed':
        return NotificationChannelId.analysisChannel;
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
    if (response.payload != null) {
      _handleNotificationNavigation(response.payload!);
    }
  }

  /// 메시지 탭 핸들러 설정
  void _setupMessageTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('백그라운드 알림 탭: ${message.messageId}');
      final data = message.data;
      _handleNotificationNavigation(data);
    });
  }

  /// 알림 네비게이션 처리
  void _handleNotificationNavigation(dynamic payload) {
    if (_navigatorKey?.currentContext == null) {
      debugPrint('Navigator context not available');
      return;
    }

    final context = _navigatorKey!.currentContext!;

    try {
      // payload가 String이면 JSON 파싱, 아니면 Map으로 사용
      final Map<String, dynamic> data = payload is String
          ? jsonDecode(payload) as Map<String, dynamic>
          : payload as Map<String, dynamic>;

      final type = data['type'] as String?;
      final route = data['route'] as String?;

      // route가 지정되어 있으면 해당 경로로 이동
      if (route != null) {
        context.go(route);
        return;
      }

      // 타입별 기본 라우트
      switch (type) {
        case 'todo':
        case 'event':
          context.go('/home');
          break;
        case 'chat':
          // 추후 채팅 화면 구현 시
          context.go('/home');
          break;
        case 'business_review':
        case 'analysis_complete':
        case 'analysis_failed':
          // 사업 검토 또는 분석 작업 관련 알림
          final jobType = data['jobType'] as String?;
          if (jobType == 'psychology_test') {
            context.go('/tools/psychology/history');
          } else {
            context.go('/tools/business/history');
          }
          break;
        default:
          context.go('/home');
      }
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
      // 에러 시 홈으로 이동
      context.go('/home');
    }
  }

  /// 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM 토큰 갱신: $newToken');

      // userId가 설정되어 있으면 자동으로 Firestore에 저장
      if (_currentUserId != null) {
        try {
          await saveTokenToFirestore(_currentUserId!);
          debugPrint('✅ 갱신된 FCM 토큰 저장 완료');
        } catch (e) {
          debugPrint('❌ 갱신된 FCM 토큰 저장 실패: $e');
        }
      }
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
    try {
      if (kIsWeb) {
        // 웹에서는 VAPID 키가 필요 (공개 키이므로 코드에 포함해도 안전)
        // Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
        const vapidKey = '***REMOVED_FCM_VAPID_KEY***';
        return await _messaging.getToken(vapidKey: vapidKey);
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ FCM 토큰 가져오기 실패: $e');
      return null;
    }
  }

  /// FCM 토큰 Firestore에 저장
  Future<void> saveTokenToFirestore(String userId) async {
    try {
      // 1. FCM 토큰 가져오기
      final token = await getToken();
      if (token == null) {
        debugPrint('❌ FCM 토큰을 가져올 수 없습니다');
        return;
      }

      debugPrint('📱 FCM 토큰 획득: ${token.substring(0, 20)}...');

      // 2. Firestore에서 사용자 문서 조회
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      // 3. 문서가 없으면 생성
      if (!userDoc.exists) {
        debugPrint('📝 사용자 문서 없음. 새로 생성합니다.');
        await userRef.set({
          'fcmTokens': [token],
        }, SetOptions(merge: true));
        debugPrint('✅ FCM 토큰 저장 완료 (새 문서): $userId');
        return;
      }

      // 4. 기존 토큰 목록 확인
      final data = userDoc.data();
      final List<String> existingTokens = data != null && data.containsKey('fcmTokens')
          ? List<String>.from(data['fcmTokens'] ?? [])
          : [];

      // 5. 이미 토큰이 있으면 스킵
      if (existingTokens.contains(token)) {
        debugPrint('ℹ️ FCM 토큰이 이미 등록되어 있습니다: $userId');
        return;
      }

      // 6. 토큰이 없으면 추가
      debugPrint('➕ 새 FCM 토큰 추가 중...');
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

      debugPrint('✅ FCM 토큰 저장 완료: $userId (총 ${existingTokens.length + 1}개 기기)');
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 실패: $e');
      rethrow; // 에러를 상위로 전달하여 로깅 가능하게
    }
  }

  /// FCM 토큰 Firestore에서 제거 (로그아웃 시)
  Future<void> removeTokenFromFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token == null) return;

      final userRef = _firestore.collection('users').doc(userId);

      // 토큰 배열에서 제거 (merge를 사용하여 안전하게 처리)
      await userRef.set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM 토큰 제거 완료: $userId');
    } catch (e) {
      debugPrint('❌ FCM 토큰 제거 실패: $e');
    }
  }

  /// 앱이 종료된 상태에서 알림 탭으로 앱 열기
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  /// 초기 메시지 확인 및 네비게이션 처리
  Future<void> handleInitialMessage() async {
    final initialMessage = await getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Processing initial message: ${initialMessage.data}');
      _handleNotificationNavigation(initialMessage.data);
    }
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
