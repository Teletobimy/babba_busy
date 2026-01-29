import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'shared/providers/group_provider.dart';
import 'services/firebase/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수 로드
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ 환경변수 로드 성공!');
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    debugPrint('GEMINI_API_KEY 설정: ${apiKey.isNotEmpty} (${apiKey.length}자)');
  } catch (e) {
    debugPrint('ℹ️ .env 파일 없음 (프로덕션 모드): $e');
  }

  // 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 화면 방향 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 날짜 포맷 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase 초기화 성공!');

    // FCM 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // NotificationService 초기화
    final notificationService = NotificationService();
    await notificationService.initialize();

    // 알림 권한 요청
    await notificationService.requestPermission();
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
  }

  // ProviderContainer 생성 및 온보딩 상태 초기화
  final container = ProviderContainer();
  await initOnboardingState(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FamilyHubApp(),
    ),
  );
}
