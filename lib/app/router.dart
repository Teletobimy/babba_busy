import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/providers/auth_provider.dart';
import '../shared/providers/group_provider.dart';
import '../services/firebase/notification_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/tools/tools_hub_screen.dart';
import '../features/tools/business/business_review_screen.dart';
import '../features/tools/business/business_history_screen.dart';
import '../features/tools/psychology/psychology_hub_screen.dart';
import '../features/tools/psychology/psychology_test_screen.dart';
import '../features/tools/psychology/psychology_history_screen.dart';
import '../features/settings/settings_screen.dart';
import 'main_shell.dart';

/// Navigator Key for notifications
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 라우터 리다이렉션 관리를 위한 Notifier
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isCompletingOnboarding = false;
  bool _hasInitializedGroup = false;

  RouterNotifier(this._ref) {
    // 관련 Provider들의 상태 변화를 감시하여 리다이렉션 트리거
    // onboardingCompletedProvider는 listen하지 않음 - redirect 내에서 상태 변경 시 무한 루프 방지
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(userMembershipsProvider, (previous, next) {
      // 멤버십 데이터가 처음 로드되었을 때 마지막 선택 그룹 복원
      if (!_hasInitializedGroup && next.hasValue && (next.value?.isNotEmpty ?? false)) {
        _hasInitializedGroup = true;
        _initializeSelectedGroupAsync();
      }
      notifyListeners();
    });
  }

  /// 비동기로 마지막 선택 그룹 복원
  Future<void> _initializeSelectedGroupAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSelected = prefs.getString('last_selected_group_id');
      if (lastSelected != null) {
        final memberships = _ref.read(userMembershipsProvider).value ?? [];
        if (memberships.any((m) => m.groupId == lastSelected)) {
          _ref.read(selectedGroupIdProvider.notifier).state = lastSelected;
        }
      }
      _ref.read(selectedGroupInitializedProvider.notifier).state = true;
    } catch (e) {
      debugPrint('Error initializing selected group: $e');
    }
  }

  /// 그룹이 있는데 온보딩 상태가 완료되지 않은 경우 백그라운드에서 완료 처리
  void _markOnboardingCompleteIfNeeded(bool hasGroups, bool onboardingCompleted) {
    if (hasGroups && !onboardingCompleted && !_isCompletingOnboarding) {
      _isCompletingOnboarding = true;
      Future.microtask(() async {
        await completeOnboarding(_ref);
        _isCompletingOnboarding = false;
      });
    }
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final memberships = _ref.read(userMembershipsProvider);
    final onboardingCompleted = _ref.read(onboardingCompletedProvider);

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
      // 별도 메서드로 분리하여 중복 호출 방지
      _markOnboardingCompleteIfNeeded(hasGroups, onboardingCompleted);
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

  // NotificationService에 Navigator Key 전달 및 초기 메시지 처리
  Future.microtask(() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.setNavigatorKey(rootNavigatorKey);

      // 앱 종료 상태에서 알림 탭으로 실행된 경우 자동 네비게이션
      await notificationService.handleInitialMessage();
    } catch (e) {
      debugPrint('Error in notification initialization: $e');
    }
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
        path: '/tools/business/history',
        name: 'business-history',
        builder: (context, state) => const BusinessHistoryScreen(),
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
