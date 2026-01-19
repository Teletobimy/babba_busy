import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/providers/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/family_setup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/todo/todo_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/tools/tools_hub_screen.dart';
import '../features/settings/settings_screen.dart';
import '../main.dart' show firebaseInitialized;
import 'main_shell.dart';

/// 데모 모드 Provider (Firebase 연결 여부에 따라 자동 설정)
/// - Firebase 초기화 성공: 데모 모드 OFF (실제 데이터 사용)
/// - Firebase 초기화 실패: 데모 모드 ON (샘플 데이터 사용)
final demoModeProvider = StateProvider<bool>((ref) => !firebaseInitialized);

/// 라우터 Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final memberState = ref.watch(currentMemberProvider);
  final demoMode = ref.watch(demoModeProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // 데모 모드에서는 리다이렉트 없이 바로 홈으로
      if (demoMode) {
        return null;
      }

      final isLoggedIn = authState.value != null;
      final hasFamilySetup = memberState.value != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isFamilySetup = state.matchedLocation == '/family-setup';

      // 로그인하지 않은 경우
      if (!isLoggedIn) {
        if (!isAuthRoute) return '/auth/login';
        return null;
      }

      // 로그인했지만 가족 설정이 안 된 경우
      if (!hasFamilySetup && !isFamilySetup) {
        return '/family-setup';
      }

      // 로그인한 상태에서 인증 페이지 접근 시
      if (isLoggedIn && hasFamilySetup && (isAuthRoute || isFamilySetup)) {
        return '/home';
      }

      return null;
    },
    routes: [
      // 인증 라우트
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      // 가족 설정
      GoRoute(
        path: '/family-setup',
        name: 'family-setup',
        builder: (context, state) => const FamilySetupScreen(),
      ),
      // 메인 쉘 (하단 네비게이션)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CalendarScreen(),
            ),
          ),
          GoRoute(
            path: '/tools',
            name: 'tools',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ToolsHubScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // 할일 상세 (전체 화면)
      GoRoute(
        path: '/todo/:id',
        name: 'todo-detail',
        builder: (context, state) => TodoScreen(
          todoId: state.pathParameters['id'],
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('페이지를 찾을 수 없습니다: ${state.error}'),
      ),
    ),
  );
});
