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
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
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

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

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
      case 'album':
        return NotificationChannelId.defaultChannel;
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

  /// 유효한 라우트 목록 (라우터에 정의된 경로만)
  static const Set<String> _validRoutes = {
    '/home',
    '/calendar',
    '/tools',
    '/settings',
    '/tools/business',
    '/tools/business/history',
    '/tools/psychology',
    '/tools/psychology/history',
    '/memo/category-analysis/history',
  };

  /// 라우트 유효성 검사
  bool _isValidRoute(String route) {
    // 정확히 일치하거나 파라미터가 있는 라우트 패턴 체크
    if (_validRoutes.contains(route)) return true;
    // /tools/psychology/test/{testType} 패턴 체크
    if (route.startsWith('/tools/psychology/test/')) return true;
    // /memo/category-analysis/{analysisId} 패턴 체크
    if (route.startsWith('/memo/category-analysis/')) return true;
    return false;
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

      debugPrint('🔔 알림 탭 - type: $type, route: $route');
      debugPrint('🔔 알림 데이터: $data');

      // route가 지정되어 있고 유효하면 해당 경로로 이동
      if (route != null && _isValidRoute(route)) {
        debugPrint('🔔 유효한 route로 이동: $route');
        context.go(route);
        return;
      }

      // 타입별 기본 라우트
      switch (type) {
        case 'todo':
        case 'event':
          debugPrint('🔔 할일/일정 알림 → /home');
          context.go('/home');
          break;
        case 'chat':
          debugPrint('🔔 채팅 알림 → /home');
          context.go('/home');
          break;
        case 'business_review':
          debugPrint('🔔 사업 검토 알림 → /tools/business/history');
          context.go('/tools/business/history');
          break;
        case 'analysis_complete':
        case 'analysis_failed':
          // 분석 작업 관련 알림 - jobType으로 구분
          final jobType = data['jobType'] as String?;
          if (jobType == 'psychology_test') {
            debugPrint('🔔 심리 검사 알림 → /tools/psychology/history');
            context.go('/tools/psychology/history');
          } else if (jobType == 'business_review') {
            debugPrint('🔔 사업 분석 알림 → /tools/business/history');
            context.go('/tools/business/history');
          } else if (jobType == 'memo_category_analysis') {
            debugPrint('🔔 메모 카테고리 분석 알림 → /memo/category-analysis/history');
            context.go('/memo/category-analysis/history');
          } else {
            debugPrint('🔔 분석 알림(기본) → /home');
            context.go('/home');
          }
          break;
        case 'album':
          debugPrint('🔔 앨범 알림 → /home');
          context.go('/home');
          break;
        default:
          debugPrint('🔔 기본 알림 → /home');
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
    debugPrint('🔔 알림 권한 요청 시작...');

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('🔔 알림 권한 상태: ${settings.authorizationStatus}');

    final isGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('🔔 알림 권한 결과: ${isGranted ? '✅ 허용' : '❌ 거부'}');

    return isGranted;
  }

  /// FCM 토큰 가져오기
  Future<String?> getToken() async {
    try {
      debugPrint('🔑 FCM 토큰 요청 시작 (웹: $kIsWeb)');

      if (kIsWeb) {
        // 웹에서는 VAPID 키가 필요
        // Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
        // --dart-define=FCM_VAPID_KEY=... 로 주입
        const vapidKey = String.fromEnvironment('FCM_VAPID_KEY');
        debugPrint('🌐 웹 FCM 토큰 요청 (VAPID: ${vapidKey.length > 20 ? vapidKey.substring(0, 20) : vapidKey}...)');
        final token = await _messaging.getToken(vapidKey: vapidKey);
        debugPrint(
          '🌐 웹 FCM 토큰 결과: ${token != null ? '${token.substring(0, 20)}...' : 'NULL'}',
        );
        return token;
      }

      final token = await _messaging.getToken();
      debugPrint(
        '📱 네이티브 FCM 토큰 결과: ${token != null ? '${token.substring(0, 20)}...' : 'NULL'}',
      );
      return token;
    } catch (e, stack) {
      debugPrint('❌ FCM 토큰 가져오기 실패: $e');
      debugPrint('❌ Stack: $stack');
      return null;
    }
  }

  /// FCM 토큰 Firestore에 저장
  ///
  /// Race Condition 방지를 위해 FieldValue.arrayUnion 사용:
  /// - Firestore 서버에서 atomic하게 중복 체크 및 추가 수행
  /// - 여러 기기에서 동시에 토큰을 추가해도 데이터 일관성 보장
  /// - SetOptions(merge: true)로 문서 존재 여부와 관계없이 안전하게 처리
  Future<void> saveTokenToFirestore(String userId) async {
    debugPrint('💾 saveTokenToFirestore 시작: $userId');

    try {
      // 1. FCM 토큰 가져오기
      final token = await getToken();
      if (token == null) {
        debugPrint('[FCM] 토큰을 가져올 수 없습니다');
        return;
      }

      debugPrint('[FCM] 토큰 획득: ${token.substring(0, 20)}...');

      // 2. Atomic하게 토큰 추가 (문서 존재 여부와 관계없이 동작)
      // - FieldValue.arrayUnion: 서버에서 중복 체크 후 추가 (이미 있으면 무시)
      // - SetOptions(merge: true): 문서가 없으면 생성, 있으면 해당 필드만 업데이트
      // - 이 조합으로 Race Condition 없이 안전하게 토큰 저장
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] 토큰 저장 완료: $userId');
    } catch (e) {
      debugPrint('[FCM] 토큰 저장 실패: $e');
      rethrow; // 에러를 상위로 전달하여 로깅 가능하게
    }
  }

  /// FCM 토큰 Firestore에서 제거 (로그아웃 시)
  ///
  /// FieldValue.arrayRemove로 atomic하게 토큰 제거:
  /// - 토큰이 없어도 에러 없이 처리
  /// - 여러 기기에서 동시에 제거해도 안전
  Future<void> removeTokenFromFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('[FCM] 제거할 토큰이 없습니다');
        return;
      }

      final userRef = _firestore.collection('users').doc(userId);

      // Atomic하게 토큰 제거 (없어도 에러 없음)
      await userRef.set({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] 토큰 제거 완료: $userId');
    } catch (e) {
      debugPrint('[FCM] 토큰 제거 실패: $e');
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
