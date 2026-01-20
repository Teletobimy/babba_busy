import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/providers/auth_provider.dart';
import '../shared/providers/group_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/todo/todo_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/tools/tools_hub_screen.dart';
import '../features/tools/business/business_review_screen.dart';
import '../features/tools/psychology/psychology_hub_screen.dart';
import '../features/tools/psychology/psychology_test_screen.dart';
import '../features/tools/psychology/psychology_history_screen.dart';
import '../features/settings/settings_screen.dart';
import '../main.dart' show firebaseInitialized;
import 'main_shell.dart';

/// 데모 모드 Provider (Firebase 연결 여부에 따라 자동 설정)
final demoModeProvider = StateProvider<bool>((ref) => !firebaseInitialized);

/// 라우터 리다이렉션 관리를 위한 Notifier
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // 관련 Provider들의 상태 변화를 감시하여 리다이렉션 트리거
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(userMembershipsProvider, (_, __) => notifyListeners());
    _ref.listen(onboardingCompletedProvider, (_, __) => notifyListeners());
    _ref.listen(demoModeProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final memberships = _ref.read(userMembershipsProvider);
    final demoMode = _ref.read(demoModeProvider);
    final onboardingCompleted = _ref.read(onboardingCompletedProvider);

    // 데모 모드에서는 리다이렉트 없이 바로 홈으로
    if (demoMode) return null;

    final isLoggedIn = authState.valueOrNull != null;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    final isOnboarding = state.matchedLocation == '/onboarding';

    // 1. 로그인하지 않은 경우
    if (!isLoggedIn) {
      if (!isAuthRoute) return '/auth/login';
      return null;
    }

    // 2. 로그인했지만 아직 멤버십 데이터를 로딩 중인 경우 리다이렉트 대기 (Flash 방지)
    // 앱 시작 시 memberships가 null/Loading인 동안은 /home 시도 방지
    if (memberships.isLoading && !isOnboarding && !isAuthRoute) return null;

    final hasGroups = (memberships.valueOrNull ?? []).isNotEmpty;

    // 3. 로그인했지만 그룹이 없고 온보딩을 아직 안 한 경우
    // 만약 그룹이 이미 있다면 (다른 기기에서 생성했거나 등) 온보딩을 건너뜁니다.
    if (!isOnboarding && !isAuthRoute) {
      if (!hasGroups && !onboardingCompleted) {
        return '/onboarding';
      }
      // 그룹이 있는데 온보딩 상태가 아니면 온보딩 완료로 간주 (기기 이동 등)
      if (hasGroups && !onboardingCompleted) {
        Future.microtask(() => completeOnboarding(_ref));
      }
    }

    // 4. 로그인한 상태에서 인증 페이지나 불필요한 온보딩에 접근 시 홈으로
    if (isLoggedIn && (isAuthRoute || (hasGroups && isOnboarding) || (onboardingCompleted && isOnboarding))) {
      return '/home';
    }

    return null;
  }
}

/// RouterNotifier Provider
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// 라우터 Provider
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    debugLogDiagnostics: true,
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
      // 온보딩 (그룹 설정)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
      // AI 도구 라우트 (독립 화면)
      GoRoute(
        path: '/tools/business',
        name: 'business-review',
        builder: (context, state) => const BusinessReviewScreen(),
      ),
      GoRoute(
        path: '/tools/psychology',
        name: 'psychology-hub',
        builder: (context, state) => const PsychologyHubScreen(),
      ),
      GoRoute(
        path: '/tools/psychology/test/:testType',
        name: 'psychology-test',
        builder: (context, state) {
          final testType = state.pathParameters['testType'] ?? 'big5';
          return PsychologyTestScreen(testType: testType);
        },
      ),
      GoRoute(
        path: '/tools/psychology/history',
        name: 'psychology-history',
        builder: (context, state) => const PsychologyHistoryScreen(),
      ),
    ],
  );
});
