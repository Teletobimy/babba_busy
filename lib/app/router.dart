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
    debugPrint('[RouterNotifier] 🔧 Constructor called');

    // 1. 인증 상태 변경 감시
    _ref.listen(authStateProvider, (previous, next) {
      debugPrint('[RouterNotifier] 🔐 authStateProvider changed: ${next?.value?.uid}');
      // 로그아웃 시 초기화 플래그 및 Provider 상태 리셋
      if (next?.value == null && previous?.value != null) {
        debugPrint('[RouterNotifier] 🔓 User logged out, resetting all initialization state');
        _hasInitializedGroup = false;
        _ref.read(selectedGroupInitializedProvider.notifier).state = false;
        _ref.read(selectedGroupIdProvider.notifier).state = null;
      }
      notifyListeners();
    });

    // 2. 멤버십 데이터 변경 감시
    _ref.listen(userMembershipsProvider, (previous, next) {
      debugPrint('[RouterNotifier] 👥 userMembershipsProvider changed: ${next.value?.length} memberships');
      // 멤버십 데이터가 처음 로드되었을 때 마지막 선택 그룹 복원
      // 단, 이미 초기화 완료된 경우(onboarding에서 직접 초기화) 스킵
      final alreadyInitialized = _ref.read(selectedGroupInitializedProvider);
      if (!_hasInitializedGroup && !alreadyInitialized && next.hasValue && (next.value?.isNotEmpty ?? false)) {
        debugPrint('[RouterNotifier] 🎯 First time memberships loaded, initializing group');
        _hasInitializedGroup = true;
        _initializeSelectedGroupAsync();
      }
      // 초기화 완료된 경우에만 notify (race condition 방지)
      if (alreadyInitialized || _ref.read(selectedGroupInitializedProvider)) {
        notifyListeners();
      }
    });

    // 3. 핵심 수정: selectedGroupIdProvider 변경 감시
    _ref.listen(selectedGroupIdProvider, (previous, next) {
      debugPrint('[RouterNotifier] 🎯 selectedGroupIdProvider changed: $previous -> $next');
      if (_ref.read(selectedGroupInitializedProvider)) {
        notifyListeners();
      }
    });

    // 4. 핵심 수정: 초기화 완료 상태 감시
    _ref.listen(selectedGroupInitializedProvider, (previous, next) {
      debugPrint('[RouterNotifier] ✅ selectedGroupInitializedProvider changed: $previous -> $next');
      if (next == true) {
        notifyListeners();
      }
    });
  }

  /// 비동기로 마지막 선택 그룹 복원 또는 첫 번째 그룹으로 초기화
  Future<void> _initializeSelectedGroupAsync() async {
    // 이미 초기화 완료된 경우 스킵 (onboarding_screen에서 직접 초기화한 경우)
    if (_ref.read(selectedGroupInitializedProvider)) {
      debugPrint('[RouterNotifier] ⚠️ Already initialized, skipping _initializeSelectedGroupAsync');
      return;
    }

    try {
      debugPrint('[RouterNotifier] 🔄 Initializing selected group...');
      final memberships = _ref.read(userMembershipsProvider).value ?? [];

      if (memberships.isEmpty) {
        debugPrint('[RouterNotifier] ⚠️ No memberships, skipping group initialization');
        _ref.read(selectedGroupInitializedProvider.notifier).state = true;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSelected = prefs.getString('last_selected_group_id');
      debugPrint('[RouterNotifier] 💾 Last selected group from prefs: $lastSelected');

      // 로컬 저장소에 저장된 그룹이 유효하면 사용
      if (lastSelected != null && memberships.any((m) => m.groupId == lastSelected)) {
        debugPrint('[RouterNotifier] ✅ Setting selected group to: $lastSelected');
        _ref.read(selectedGroupIdProvider.notifier).state = lastSelected;
      } else {
        // 첫 번째 그룹으로 초기화
        final firstGroupId = memberships.first.groupId;
        debugPrint('[RouterNotifier] 🎯 Setting first group: $firstGroupId');
        _ref.read(selectedGroupIdProvider.notifier).state = firstGroupId;
      }

      _ref.read(selectedGroupInitializedProvider.notifier).state = true;
      debugPrint('[RouterNotifier] ✅ Group initialization completed');
    } catch (e) {
      debugPrint('[RouterNotifier] ❌ Error initializing selected group: $e');
      // 에러가 발생해도 초기화 완료로 표시하여 앱이 영구 대기 상태에 빠지지 않도록
      _ref.read(selectedGroupInitializedProvider.notifier).state = true;
    }
  }

  /// 그룹이 있는데 온보딩 상태가 완료되지 않은 경우 백그라운드에서 완료 처리
  void _markOnboardingCompleteIfNeeded(bool hasGroups, bool onboardingCompleted) {
    if (hasGroups && !onboardingCompleted && !_isCompletingOnboarding) {
      debugPrint('[RouterNotifier] 📝 Marking onboarding as complete (hasGroups=true, onboardingCompleted=false)');
      _isCompletingOnboarding = true;
      Future.microtask(() async {
        try {
          await completeOnboarding(_ref);
          debugPrint('[RouterNotifier] ✅ Onboarding marked as complete');
        } catch (e) {
          debugPrint('[RouterNotifier] ❌ Error completing onboarding: $e');
        } finally {
          _isCompletingOnboarding = false;
        }
      });
    }
  }

  String? redirect(BuildContext context, GoRouterState state) {
    debugPrint('[Router] 🚦 === REDIRECT START === Location: ${state.matchedLocation}');
    final authState = _ref.read(authStateProvider);
    final memberships = _ref.read(userMembershipsProvider);
    final onboardingCompleted = _ref.read(onboardingCompletedProvider);
    final isGroupInitialized = _ref.read(selectedGroupInitializedProvider);
    final selectedGroupId = _ref.read(selectedGroupIdProvider);

    final isLoggedIn = authState.valueOrNull != null;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    final isOnboarding = state.matchedLocation == '/onboarding';

    debugPrint('[Router]   isLoggedIn: $isLoggedIn');
    debugPrint('[Router]   memberships.isLoading: ${memberships.isLoading}');
    debugPrint('[Router]   memberships.value?.length: ${memberships.valueOrNull?.length}');
    debugPrint('[Router]   onboardingCompleted: $onboardingCompleted');
    debugPrint('[Router]   isGroupInitialized: $isGroupInitialized');
    debugPrint('[Router]   selectedGroupId: $selectedGroupId');
    debugPrint('[Router]   isAuthRoute: $isAuthRoute');
    debugPrint('[Router]   isOnboarding: $isOnboarding');

    // 1. 로그인하지 않은 경우
    if (!isLoggedIn) {
      debugPrint('[Router] ❌ Not logged in, redirect to /auth/login');
      if (!isAuthRoute) return '/auth/login';
      debugPrint('[Router] ✅ Already on auth route, no redirect');
      return null;
    }

    // 2. 로그인했지만 아직 멤버십 데이터를 로딩 중인 경우 리다이렉트 대기 (Flash 방지)
    if (memberships.isLoading && !isOnboarding && !isAuthRoute) {
      debugPrint('[Router] ⏳ Memberships loading, wait...');
      return null;
    }

    final hasGroups = (memberships.valueOrNull ?? []).isNotEmpty;
    debugPrint('[Router]   hasGroups: $hasGroups');

    // 3. 핵심 수정: 그룹이 있지만 초기화가 완료되지 않은 경우 대기
    // 이 조건이 없으면 selectedGroupIdProvider가 null인 상태에서 /home으로 이동하여
    // 모든 Feature Provider가 빈 데이터를 반환함
    if (hasGroups && !isGroupInitialized && !isOnboarding && !isAuthRoute) {
      debugPrint('[Router] ⏳ Has groups but not initialized, waiting...');
      return null;
    }

    // 4. 로그인했지만 그룹이 없고 온보딩을 아직 안 한 경우
    if (!isOnboarding && !isAuthRoute) {
      if (!hasGroups && !onboardingCompleted) {
        debugPrint('[Router] 🎯 No groups & no onboarding, redirect to /onboarding');
        return '/onboarding';
      }
      // 그룹이 있는데 온보딩 상태가 아니면 온보딩 완료로 간주 (기기 이동 등)
      _markOnboardingCompleteIfNeeded(hasGroups, onboardingCompleted);
    }

    // 5. 로그인한 상태에서 인증 페이지나 불필요한 온보딩에 접근 시 홈으로
    if (isLoggedIn && (isAuthRoute || (hasGroups && isOnboarding) || (onboardingCompleted && isOnboarding))) {
      debugPrint('[Router] 🏠 Redirect to /home (logged in & (auth route OR has groups OR onboarding completed))');
      return '/home';
    }

    debugPrint('[Router] ✅ No redirect needed');
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
