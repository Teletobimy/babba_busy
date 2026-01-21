import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

/// 테마 모드 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.system;
});

/// 메인 앱 위젯
class FamilyHubApp extends ConsumerWidget {
  const FamilyHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'BABBA',
      debugShowCheckedModeBanner: false,
      
      // 테마 설정
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      
      // 라우터 설정
      routerConfig: router,
      
      // 한국어 로케일
      locale: const Locale('ko', 'KR'),
    );
  }
}
