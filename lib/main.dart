import 'package:flutter/foundation.dart';
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

/// --dart-define 으로 주입된 환경변수를 읽는 헬퍼.
/// 빌드 시 `flutter build --dart-define=GEMINI_API_KEY=xxx` 형태로 전달.
String _envVar(String key) {
  // --dart-define 값 우선 (release 빌드용)
  const dartDefines = {
    'GEMINI_API_KEY': String.fromEnvironment('GEMINI_API_KEY'),
  };
  final define = dartDefines[key] ?? '';
  if (define.isNotEmpty) return define;

  // fallback: dotenv (개발 모드용)
  return dotenv.env[key] ?? '';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수 로드: release 모드에서는 .env 파일이 없어도 정상 동작
  // --dart-define 값이 있으면 .env 로드를 건너뛸 수 있음
  if (kDebugMode || kProfileMode) {
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('환경변수 .env 로드 성공 (개발 모드)');
    } catch (e) {
      debugPrint('.env 파일 없음 (dart-define 사용): $e');
    }
  } else {
    // Release 모드: .env 번들 없이 dart-define 사용
    // .env 파일이 assets에 남아있을 수 있으므로 시도는 하되 실패 무시
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Release에서 .env 없음은 정상 — dart-define으로 주입됨
    }
  }

  final apiKey = _envVar('GEMINI_API_KEY');
  debugPrint('GEMINI_API_KEY 설정: ${apiKey.isNotEmpty} (${apiKey.length}자)');

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
