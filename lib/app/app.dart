import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_theme.dart';
import '../shared/providers/auth_provider.dart';
import '../shared/providers/notification_settings_provider.dart';
import '../shared/providers/loading_provider.dart';
import '../shared/widgets/loading_overlay.dart';
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
    final isInitialLoading = ref.watch(isInitialLoadingProvider);

    // FCM 토큰 자동 저장 (로그인 시)
    final tokenSaver = ref.watch(fcmTokenSaverProvider);
    tokenSaver.whenOrNull(
      error: (error, stack) {
        debugPrint('FCM token save error: $error');
        debugPrint('Stack trace: $stack');
      },
    );

    // Membership 동기화 (로그인 시 한 번 실행)
    // currentUserProvider가 변경될 때만 재실행됨
    final membershipSync = ref.watch(membershipSyncProvider);
    membershipSync.whenOrNull(
      error: (error, stack) {
        debugPrint('[MembershipSync] Error: $error');
      },
    );

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

      // 로딩 오버레이 (초기 데이터 로드 중 깜빡임 방지)
      builder: (context, child) {
        // Reduced Motion 지원: 시스템 설정에 따라 애니메이션 비활성화
        if (MediaQuery.of(context).disableAnimations) {
          Animate.defaultDuration = Duration.zero;
        } else {
          Animate.defaultDuration = const Duration(milliseconds: 300);
        }
        return Stack(
          children: [
            child!,
            if (isInitialLoading)
              const LoadingOverlay(),
          ],
        );
      },
    );
  }
}
