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
import '../features/tools/community/community_hub_screen.dart';
import '../features/tools/community/community_detail_screen.dart';
import '../features/memo/memo_category_analysis_history_screen.dart';
import '../features/memo/memo_category_analysis_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import 'main_shell.dart';

/// Navigator Key for notifications
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 라우터 리다이렉션 관리를 위한 Notifier
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  bool _isCompletingOnboarding = false;
  bool _hasInitializedGroup = false;
  bool _hasEverHadGroups = false; // 세션 중 그룹 감지 이력 (일시적 빈 상태 방지)
  int _notifyCount = 0; // 디버깅: notifyListeners 호출 횟수
  int _redirectCount = 0; // 디버깅: redirect 호출 횟수

  RouterNotifier(this._ref) {
    debugPrint('[RouterNotifier] 🔧 Constructor called at ${DateTime.now()}');
    debugPrint(
      '[RouterNotifier] 🔧 Initial _hasInitializedGroup: $_hasInitializedGroup',
    );

    // 1. 인증 상태 변경 감시
    _ref.listen(authStateProvider, (previous, next) {
      final prevUid = previous?.valueOrNull?.uid;
      final nextUid = next.valueOrNull?.uid;
      debugPrint('[RouterNotifier] 🔐 authStateProvider changed:');
      debugPrint('[RouterNotifier]   previous UID: $prevUid');
      debugPrint('[RouterNotifier]   next UID: $nextUid');
      debugPrint('[RouterNotifier]   next.isLoading: ${next.isLoading}');
      debugPrint('[RouterNotifier]   next.hasValue: ${next.hasValue}');

      // 로그아웃 시 초기화 플래그 및 Provider 상태 리셋
      if (nextUid == null && prevUid != null) {
        debugPrint(
          '[RouterNotifier] 🔓 User logged out, resetting all initialization state',
        );
        _hasInitializedGroup = false;
        _hasEverHadGroups = false;
        _ref.read(selectedGroupInitializedProvider.notifier).state = false;
        _ref.read(selectedGroupIdProvider.notifier).state = null;
        _ref.read(onboardingCompletedProvider.notifier).state = false;
        _notifyCount++;
        debugPrint(
          '[RouterNotifier] 📢 notifyListeners() #$_notifyCount from authStateProvider (logout)',
        );
        notifyListeners();
        return;
      }

      // 실제 UID 변경이 있을 때만 notify (같은 UID로 토큰 갱신 등은 무시)
      if (prevUid != nextUid) {
        _notifyCount++;
        debugPrint(
          '[RouterNotifier] 📢 notifyListeners() #$_notifyCount from authStateProvider (UID changed)',
        );
        notifyListeners();
      } else {
        debugPrint(
          '[RouterNotifier]   ⏭️ Skipping notify (UID unchanged: $prevUid == $nextUid)',
        );
      }
    });

    // 2. 멤버십 데이터 변경 감시
    _ref.listen(userMembershipsProvider, (previous, next) {
      debugPrint('[RouterNotifier] 👥 userMembershipsProvider changed:');
      debugPrint(
        '[RouterNotifier]   previous count: ${previous?.value?.length}',
      );
      debugPrint('[RouterNotifier]   next count: ${next.value?.length}');
      debugPrint('[RouterNotifier]   next.isLoading: ${next.isLoading}');
      debugPrint('[RouterNotifier]   next.hasValue: ${next.hasValue}');
      debugPrint(
        '[RouterNotifier]   _hasInitializedGroup: $_hasInitializedGroup',
      );
      // 그룹 존재 이력 추적 (일시적 빈 상태에서 온보딩 리다이렉트 방지)
      if (next.hasValue && (next.value?.isNotEmpty ?? false)) {
        if (!_hasEverHadGroups) {
          debugPrint('[RouterNotifier] 🏷️ _hasEverHadGroups = true (groups detected)');
        }
        _hasEverHadGroups = true;
      }
      // 멤버십 데이터가 처음 로드되었을 때 마지막 선택 그룹 복원
      // 단, 이미 초기화 완료된 경우(onboarding에서 직접 초기화) 스킵
      final alreadyInitialized = _ref.read(selectedGroupInitializedProvider);
      debugPrint('[RouterNotifier]   alreadyInitialized: $alreadyInitialized');
      if (!_hasInitializedGroup &&
          !alreadyInitialized &&
          next.hasValue &&
          (next.value?.isNotEmpty ?? false)) {
        debugPrint(
          '[RouterNotifier] 🎯 First time memberships loaded, initializing group',
        );
        _hasInitializedGroup = true;
        _initializeSelectedGroupAsync();
      } else {
        debugPrint('[RouterNotifier]   ⏭️ Skipping initialization:');
        debugPrint(
          '[RouterNotifier]     _hasInitializedGroup=$_hasInitializedGroup',
        );
        debugPrint(
          '[RouterNotifier]     alreadyInitialized=$alreadyInitialized',
        );
        debugPrint('[RouterNotifier]     next.hasValue=${next.hasValue}');
        debugPrint(
          '[RouterNotifier]     next.value?.isNotEmpty=${next.value?.isNotEmpty}',
        );
      }
      // 초기화 완료된 경우에만 notify (race condition 방지)
      if (alreadyInitialized || _ref.read(selectedGroupInitializedProvider)) {
        _notifyCount++;
        debugPrint(
          '[RouterNotifier] 📢 notifyListeners() #$_notifyCount from userMembershipsProvider',
        );
        notifyListeners();
      } else {
        debugPrint(
          '[RouterNotifier]   ⏭️ Skipping notifyListeners (not initialized yet)',
        );
      }
    });

    // 3. 핵심 수정: selectedGroupIdProvider 변경 감시
    _ref.listen(selectedGroupIdProvider, (previous, next) {
      debugPrint(
        '[RouterNotifier] 🎯 selectedGroupIdProvider changed: $previous -> $next',
      );
      final isInitialized = _ref.read(selectedGroupInitializedProvider);
      debugPrint('[RouterNotifier]   isInitialized: $isInitialized');
      if (isInitialized) {
        _notifyCount++;
        debugPrint(
          '[RouterNotifier] 📢 notifyListeners() #$_notifyCount from selectedGroupIdProvider',
        );
        notifyListeners();
      } else {
        debugPrint(
          '[RouterNotifier]   ⏭️ Skipping notifyListeners (not initialized)',
        );
      }
    });

    // 4. 핵심 수정: 초기화 완료 상태 감시
    _ref.listen(selectedGroupInitializedProvider, (previous, next) {
      debugPrint(
        '[RouterNotifier] ✅ selectedGroupInitializedProvider changed: $previous -> $next',
      );
      // false -> true 변경 시에만 notify (한 번만 실행 보장, true -> true 무시)
      if (previous == false && next == true) {
        _notifyCount++;
        debugPrint(
          '[RouterNotifier] 📢 notifyListeners() #$_notifyCount from selectedGroupInitializedProvider',
        );
        notifyListeners();
      } else {
        debugPrint(
          '[RouterNotifier]   ⏭️ Skipping notify (not false->true transition)',
        );
      }
    });
  }

  /// 비동기로 마지막 선택 그룹 복원 또는 첫 번째 그룹으로 초기화
  Future<void> _initializeSelectedGroupAsync() async {
    // 이미 초기화 완료된 경우 스킵 (onboarding_screen에서 직접 초기화한 경우)
    if (_ref.read(selectedGroupInitializedProvider)) {
      debugPrint(
        '[RouterNotifier] ⚠️ Already initialized, skipping _initializeSelectedGroupAsync',
      );
      return;
    }

    try {
      debugPrint('[RouterNotifier] 🔄 Initializing selected group...');
      final memberships = _ref.read(userMembershipsProvider).value ?? [];

      if (memberships.isEmpty) {
        debugPrint(
          '[RouterNotifier] ⚠️ No memberships, skipping group initialization',
        );
        _ref.read(selectedGroupInitializedProvider.notifier).state = true;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSelected = prefs.getString('last_selected_group_id');
      debugPrint(
        '[RouterNotifier] 💾 Last selected group from prefs: $lastSelected',
      );

      // 로컬 저장소에 저장된 그룹이 유효하면 사용
      if (lastSelected != null &&
          memberships.any((m) => m.groupId == lastSelected)) {
        debugPrint(
          '[RouterNotifier] ✅ Setting selected group to: $lastSelected',
        );
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
  void _markOnboardingCompleteIfNeeded(
    bool hasGroups,
    bool onboardingCompleted,
  ) {
    if (hasGroups && !onboardingCompleted && !_isCompletingOnboarding) {
      debugPrint(
        '[RouterNotifier] 📝 Marking onboarding as complete (hasGroups=true, onboardingCompleted=false)',
      );
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
    _redirectCount++;
    debugPrint(
      '[Router] 🚦 ═══════════════════════════════════════════════════',
    );
    debugPrint('[Router] 🚦 REDIRECT #$_redirectCount at ${DateTime.now()}');
    debugPrint('[Router] 🚦 Location: ${state.matchedLocation}');
    debugPrint(
      '[Router] 🚦 ═══════════════════════════════════════════════════',
    );
    final authState = _ref.read(authStateProvider);
    final memberships = _ref.read(userMembershipsProvider);
    final onboardingCompleted = _ref.read(onboardingCompletedProvider);
    final isGroupInitialized = _ref.read(selectedGroupInitializedProvider);
    final selectedGroupId = _ref.read(selectedGroupIdProvider);

    final isLoggedIn = authState.valueOrNull != null;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isCommunityRoute =
        state.matchedLocation == '/tools/community' ||
        state.matchedLocation.startsWith('/tools/community/');

    debugPrint('[Router]   authState.isLoading: ${authState.isLoading}');
    debugPrint('[Router]   authState.hasValue: ${authState.hasValue}');
    debugPrint(
      '[Router]   authState.value?.uid: ${authState.valueOrNull?.uid}',
    );
    debugPrint('[Router]   isLoggedIn: $isLoggedIn');
    debugPrint('[Router]   memberships.isLoading: ${memberships.isLoading}');
    debugPrint('[Router]   memberships.hasValue: ${memberships.hasValue}');
    debugPrint(
      '[Router]   memberships.value?.length: ${memberships.valueOrNull?.length}',
    );
    debugPrint('[Router]   onboardingCompleted: $onboardingCompleted');
    debugPrint('[Router]   isGroupInitialized: $isGroupInitialized');
    debugPrint('[Router]   selectedGroupId: $selectedGroupId');
    debugPrint('[Router]   _hasInitializedGroup: $_hasInitializedGroup');
    debugPrint('[Router]   _hasEverHadGroups: $_hasEverHadGroups');
    debugPrint('[Router]   isAuthRoute: $isAuthRoute');
    debugPrint('[Router]   isOnboarding: $isOnboarding');
    debugPrint('[Router]   isCommunityRoute: $isCommunityRoute');

    // 1. 로그인하지 않은 경우
    if (!isLoggedIn) {
      debugPrint('[Router] ❌ DECISION: Not logged in');
      if (!isAuthRoute && !isCommunityRoute) {
        debugPrint('[Router] ➡️ REDIRECT to /auth/login');
        return '/auth/login';
      }
      debugPrint('[Router] ✅ STAY on public/auth route');
      return null;
    }

    // 2. 로그인했지만 아직 멤버십 데이터를 로딩 중이거나 에러인 경우 리다이렉트 대기 (Flash 방지)
    if ((memberships.isLoading || memberships.hasError) && !isOnboarding && !isCommunityRoute) {
      debugPrint('[Router] ⏳ WAIT: Memberships loading=${memberships.isLoading} error=${memberships.hasError}');
      return null;
    }

    final hasGroups = (memberships.valueOrNull ?? []).isNotEmpty;
    debugPrint('[Router]   hasGroups: $hasGroups');

    // 3. 핵심 수정: 그룹이 있지만 초기화가 완료되지 않은 경우 대기
    // 이 조건이 없으면 selectedGroupIdProvider가 null인 상태에서 /home으로 이동하여
    // 모든 Feature Provider가 빈 데이터를 반환함
    if (hasGroups &&
        !isGroupInitialized &&
        !isOnboarding &&
        !isAuthRoute &&
        !isCommunityRoute) {
      debugPrint(
        '[Router] ⏳ WAIT: Has groups ($hasGroups) but not initialized ($isGroupInitialized)',
      );
      debugPrint(
        '[Router]   Waiting for _initializeSelectedGroupAsync to complete...',
      );
      return null;
    }

    // 4. 로그인했고 그룹이 없으면 온보딩으로 이동
    // 핵심 수정: _hasEverHadGroups 플래그로 일시적 빈 상태에서의 잘못된 리다이렉트 방지
    if (!isOnboarding && !isAuthRoute && !isCommunityRoute) {
      if (!hasGroups) {
        // 이전에 그룹을 감지한 적 있으면 → 일시적 빈 상태이므로 대기
        if (_hasEverHadGroups) {
          debugPrint(
            '[Router] ⏳ WAIT: hasGroups=false but _hasEverHadGroups=true (temporary empty state)',
          );
          return null;
        }
        // memberships가 확실히 로드 완료 + 빈 리스트인 경우에만 온보딩
        if (memberships.hasValue && (memberships.value?.isEmpty ?? true)) {
          debugPrint(
            '[Router] 🎯 DECISION: Confirmed no groups, redirect to onboarding',
          );
          debugPrint('[Router] ➡️ REDIRECT to /onboarding');
          return '/onboarding';
        }
        // 아직 확실하지 않으면 대기
        debugPrint(
          '[Router] ⏳ WAIT: hasGroups=false but memberships not confirmed (hasValue=${memberships.hasValue})',
        );
        return null;
      }
      // 그룹이 있는데 온보딩 상태가 아니면 온보딩 완료로 간주 (기기 이동 등)
      _markOnboardingCompleteIfNeeded(hasGroups, onboardingCompleted);
    }

    // 4-1. 로그인 사용자가 인증 페이지에 있으면 그룹 보유 여부에 따라 이동
    if (isAuthRoute) {
      // 그룹이 있거나 이전에 그룹을 감지한 적 있으면 → 홈으로
      if (hasGroups || _hasEverHadGroups) {
        debugPrint(
          '[Router] 🏠 DECISION: Logged in user on auth route -> /home (hasGroups=$hasGroups, _hasEverHadGroups=$_hasEverHadGroups)',
        );
        return '/home';
      }
      // 멤버십이 확실히 빈 리스트로 로드 완료된 경우에만 온보딩
      if (memberships.hasValue && (memberships.value?.isEmpty ?? true)) {
        debugPrint(
          '[Router] 🧭 DECISION: Logged in user with confirmed no groups -> /onboarding',
        );
        return '/onboarding';
      }
      // 멤버십 상태가 불확실하면 /home으로 (MainShell이 처리)
      debugPrint(
        '[Router] 🏠 DECISION: Memberships uncertain, defaulting to /home',
      );
      return '/home';
    }

    // 5. 로그인한 상태에서 인증 페이지나 불필요한 온보딩에 접근 시 홈으로
    // 핵심 수정: 이미 /home에 있으면 다시 /home으로 redirect하지 않음 (무한 루프 방지)
    final isAlreadyAtHome =
        state.matchedLocation == '/home' ||
        state.matchedLocation.startsWith('/home/');
    final shouldRedirectToHome =
        isLoggedIn &&
        !isAlreadyAtHome &&
        hasGroups &&
        onboardingCompleted &&
        isOnboarding;
    debugPrint('[Router]   shouldRedirectToHome check:');
    debugPrint('[Router]     isLoggedIn=$isLoggedIn');
    debugPrint('[Router]     isAlreadyAtHome=$isAlreadyAtHome');
    debugPrint('[Router]     isAuthRoute=$isAuthRoute');
    debugPrint(
      '[Router]     hasGroups && isOnboarding = $hasGroups && $isOnboarding = ${hasGroups && isOnboarding}',
    );
    debugPrint(
      '[Router]     onboardingCompleted && isOnboarding = $onboardingCompleted && $isOnboarding = ${onboardingCompleted && isOnboarding}',
    );
    debugPrint('[Router]     => shouldRedirectToHome=$shouldRedirectToHome');
    if (shouldRedirectToHome) {
      debugPrint('[Router] 🏠 DECISION: Should go to /home');
      debugPrint('[Router] ➡️ REDIRECT to /home');
      return '/home';
    }

    debugPrint(
      '[Router] ✅ NO REDIRECT needed, staying at ${state.matchedLocation}',
    );
    return null;
  }
}

/// RouterNotifier Provider
final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// 라우터 Provider
final routerProvider = Provider<GoRouter>((ref) {
  // 핵심 수정: watch -> read 변경 (watch 사용 시 RouterNotifier 재생성 시 GoRouter도 재생성됨)
  final notifier = ref.read(routerNotifierProvider);

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
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CalendarScreen()),
          ),
          GoRoute(
            path: '/tools',
            name: 'tools',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ToolsHubScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
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
      GoRoute(
        path: '/tools/community',
        name: 'community-hub',
        builder: (context, state) => const CommunityHubScreen(),
      ),
      GoRoute(
        path: '/tools/community/:communityId',
        name: 'community-detail',
        builder: (context, state) {
          final communityId = state.pathParameters['communityId'] ?? '';
          return CommunityDetailScreen(communityId: communityId);
        },
      ),
      GoRoute(
        path: '/memo/category-analysis/history',
        name: 'memo-category-analysis-history',
        builder: (context, state) => const MemoCategoryAnalysisHistoryScreen(),
      ),
      GoRoute(
        path: '/memo/category-analysis/:analysisId',
        name: 'memo-category-analysis-detail',
        builder: (context, state) {
          final analysisId = state.pathParameters['analysisId'] ?? '';
          return MemoCategoryAnalysisDetailScreen(analysisId: analysisId);
        },
      ),
    ],
  );
});
