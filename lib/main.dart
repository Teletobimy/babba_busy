import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'firebase_options.dart';

/// Firebase 초기화 성공 여부
bool firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수 로드 (개발 환경에서만 사용, 프로덕션은 --dart-define 사용)
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ 환경변수 로드 성공!');
  } catch (e) {
    // .env 파일이 없어도 OK (프로덕션에서는 --dart-define으로 주입)
    debugPrint('ℹ️ .env 파일 없음 (프로덕션 모드)');
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
    firebaseInitialized = true;
    debugPrint('✅ Firebase 초기화 성공!');
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    debugPrint('데모 모드로 실행합니다.');
  }

  runApp(
    const ProviderScope(
      child: FamilyHubApp(),
    ),
  );
}
