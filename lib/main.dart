import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Firebase 초기화 (실패해도 앱 실행 가능 - 데모 모드)
  try {
    await Firebase.initializeApp();
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
