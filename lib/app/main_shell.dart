import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../shared/providers/auth_provider.dart';
import '../shared/providers/group_provider.dart';
import '../shared/providers/update_provider.dart';
import '../shared/widgets/update_dialog.dart';
import '../services/firebase/notification_service.dart';

/// 도구 탭 컬러
const Color toolsColor = Color(0xFF5B8DEF);

/// 메인 쉘 (하단 네비게이션 바 포함)
class MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 렌더링 후 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
      _startLoadingTimeout();
    });
  }

  /// 10초 후에도 그룹 초기화가 안 되면 강제로 초기화 완료 처리
  void _startLoadingTimeout() {
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      final isInitialized = ref.read(selectedGroupInitializedProvider);
      if (!isInitialized) {
        debugPrint('[MainShell] ⏰ Loading timeout (10s) - forcing initialization');
        // 멤버십이 있으면 첫 번째 그룹으로 설정
        final memberships = ref.read(userMembershipsProvider).value ?? [];
        if (memberships.isNotEmpty && ref.read(selectedGroupIdProvider) == null) {
          final firstGroupId = memberships.first.groupId;
          debugPrint('[MainShell] ⏰ Setting first group: $firstGroupId');
          ref.read(selectedGroupIdProvider.notifier).state = firstGroupId;
        }
        ref.read(selectedGroupInitializedProvider.notifier).state = true;
      }
    });
  }

  Future<void> _initialize() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    // 1. FCM 토큰 저장 확인
    await _ensureFcmToken();

    // 2. 업데이트 체크
    await _checkForUpdate();
  }

  /// FCM 토큰이 저장되어 있는지 확인하고, 없으면 저장
  Future<void> _ensureFcmToken() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final notificationService = NotificationService();

      // userId 설정 (토큰 갱신 시 자동 저장용)
      notificationService.setCurrentUserId(user.uid);

      // 권한 확인 및 요청
      final hasPermission = await notificationService.requestPermission();
      if (!hasPermission) {
        debugPrint('⚠️ 알림 권한 거부됨');
        return;
      }

      // 토큰 저장 (내부에서 중복 체크)
      await notificationService.saveTokenToFirestore(user.uid);
      debugPrint('✅ FCM 토큰 확인/저장 완료');
    } catch (e) {
      debugPrint('❌ FCM 토큰 저장 실패: $e');
    }
  }

  Future<void> _checkForUpdate() async {
    final updateInfo = await ref.read(appUpdateProvider.future);
    if (updateInfo != null && updateInfo.updateAvailable && mounted) {
      await UpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupInitialized = ref.watch(selectedGroupInitializedProvider);
    final transitionState = ref.watch(groupTransitionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 그룹 초기화 미완료 시 로딩 화면 표시
    if (!isGroupInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.primaryDark : AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '데이터를 불러오는 중...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 메인 콘텐츠
          widget.child,
          // 그룹 전환 오버레이
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: transitionState.isTransitioning
                ? _GroupTransitionOverlay(
                    groupName: transitionState.targetGroupName,
                    isDark: isDark,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

/// 그룹 전환 오버레이 위젯
class _GroupTransitionOverlay extends StatelessWidget {
  final String? groupName;
  final bool isDark;

  const _GroupTransitionOverlay({
    this.groupName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
          .withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 로딩 인디케이터
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
              ),
            ),
            if (groupName != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                groupName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                '으로 전환 중...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/calendar')) return 1;
    if (location.startsWith('/tools')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/calendar');
        break;
      case 2:
        context.go('/tools');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Iconsax.home_2,
                activeIcon: Iconsax.home_25,
                label: '홈',
                isSelected: selectedIndex == 0,
                color: AppColors.todoColor,
                onTap: () => _onItemTapped(context, 0),
              ),
              _NavItem(
                icon: Iconsax.calendar_1,
                activeIcon: Iconsax.calendar5,
                label: '캘린더',
                isSelected: selectedIndex == 1,
                color: AppColors.calendarColor,
                onTap: () => _onItemTapped(context, 1),
              ),
              _NavItem(
                icon: Iconsax.box_1,
                activeIcon: Iconsax.box5,
                label: '도구',
                isSelected: selectedIndex == 2,
                color: toolsColor,
                onTap: () => _onItemTapped(context, 2),
              ),
              _NavItem(
                icon: Iconsax.setting_2,
                activeIcon: Iconsax.setting5,
                label: '설정',
                isSelected: selectedIndex == 3,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                onTap: () => _onItemTapped(context, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark 
        ? AppColors.textSecondaryDark 
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? color : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? color : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
