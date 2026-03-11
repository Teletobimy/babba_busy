import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/group_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // 모드: selection (선택), create (생성), join (참여), transitioning (전환 중)
  String _mode = 'selection';
  final _formKey = GlobalKey<FormState>();

  // 입력 컨트롤러
  final _groupNameController = TextEditingController();
  final _memberNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  int _selectedColorIndex = 0;
  bool _isLoading = false;
  bool _isStartingAlone = false; // 연속 클릭 방지용 락
  String? _errorMessage;
  String? _inviteCode; // 생성 완료 시 표시할 초대 코드
  bool _isTransitioningToHome = false; // 홈으로 전환 중 상태
  bool _autoRedirecting = false; // 이미 그룹 있는 사용자 자동 리다이렉트
  bool get _isBusy => _isLoading || _isStartingAlone || _isTransitioningToHome;

  @override
  void dispose() {
    _groupNameController.dispose();
    _memberNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  // 초기 화면으로 돌아가기
  void _goToSelection() {
    if (_isBusy) return;
    setState(() {
      _mode = 'selection';
      _errorMessage = null;
      _inviteCode = null;
    });
  }

  // 혼자 시작하기 (자동 생성)
  Future<void> _startAlone() async {
    // 연속 클릭 방지: 이미 실행 중이면 즉시 반환
    if (_isStartingAlone) {
      debugPrint('[OnboardingScreen] ⚠️ Already starting alone, ignoring');
      return;
    }
    _isStartingAlone = true;

    debugPrint('[OnboardingScreen] 👤 Starting alone...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다.');
      debugPrint('[OnboardingScreen] 🔐 User: ${user.uid}');

      final firestore = ref.read(firestoreProvider);
      if (firestore == null) throw Exception('Firestore 초기화 실패');

      // 1. 사용자의 기존 멤버십 확인
      debugPrint('[OnboardingScreen] 🔍 Checking existing memberships...');
      final memberships = await firestore
          .collection('memberships')
          .where('userId', isEqualTo: user.uid)
          .get();
      debugPrint(
        '[OnboardingScreen] 📋 Found ${memberships.docs.length} memberships',
      );

      // 2. "나만의 공간" 그룹이 이미 있는지 확인
      String? existingMySpaceId;
      for (final doc in memberships.docs) {
        final groupId = doc.data()['groupId'] as String;
        final groupDoc = await firestore
            .collection('families')
            .doc(groupId)
            .get();
        if (groupDoc.exists && groupDoc.data()?['name'] == '나만의 공간') {
          existingMySpaceId = groupId;
          debugPrint('[OnboardingScreen] ✅ Found existing "나만의 공간": $groupId');
          break;
        }
      }

      // 3. 이미 "나만의 공간"이 있으면 생성하지 않고 온보딩만 완료
      if (existingMySpaceId != null) {
        debugPrint(
          '[OnboardingScreen] ⏭️ Skipping creation, setting existing group',
        );
        // 핵심 수정: 기존 그룹을 selectedGroupIdProvider에 직접 설정
        ref.read(selectedGroupIdProvider.notifier).state = existingMySpaceId;
        ref.read(selectedGroupInitializedProvider.notifier).state = true;

        // SharedPreferences에도 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_selected_group_id', existingMySpaceId);

        await completeOnboarding(ref);
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // 4. "나만의 공간"이 없으면 새로 생성
      debugPrint('[OnboardingScreen] 🆕 Creating new "나만의 공간"...');
      final authService = ref.read(authServiceProvider);
      final userName = user.displayName ?? '나';

      // 랜덤 색상 선택
      final color = AppColors.memberColors[0];
      final colorHex =
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

      final result = await authService.createFamily(
        '나만의 공간', // 기본 그룹명
        userName,
        colorHex,
      );

      if (result == null) {
        throw Exception('그룹 생성에 실패했습니다.');
      }
      debugPrint('[OnboardingScreen] ✅ Created "나만의 공간": ${result.groupId}');

      // 핵심 수정: 새로 생성한 그룹을 selectedGroupIdProvider에 직접 설정
      ref.read(selectedGroupIdProvider.notifier).state = result.groupId;
      ref.read(selectedGroupInitializedProvider.notifier).state = true;

      // SharedPreferences에도 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_group_id', result.groupId);

      // 온보딩 완료 표시
      await completeOnboarding(ref);

      // 성공 - 라우터가 자동으로 리다이렉트
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('[OnboardingScreen] ✅ Onboarding completed successfully');
    } catch (e) {
      debugPrint('[OnboardingScreen] ❌ Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _isStartingAlone = false; // 락 해제
    }
  }

  // 그룹 생성 또는 참여 제출
  Future<void> _handleSubmit() async {
    if (_isBusy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final color = AppColors.memberColors[_selectedColorIndex];
      final colorHex =
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

      if (_mode == 'create') {
        final result = await authService.createFamily(
          _groupNameController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );

        if (result == null) {
          throw Exception('그룹 생성에 실패했습니다.');
        }

        // 핵심 수정: 새로 생성한 그룹을 selectedGroupIdProvider에 직접 설정
        ref.read(selectedGroupIdProvider.notifier).state = result.groupId;
        ref.read(selectedGroupInitializedProvider.notifier).state = true;

        // SharedPreferences에도 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_selected_group_id', result.groupId);

        // 초대 코드 성공 화면을 먼저 보여준 뒤, 시작하기에서 온보딩 완료 처리
        setState(() => _inviteCode = result.inviteCode);
      } else if (_mode == 'join') {
        await authService.joinFamily(
          _inviteCodeController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );

        // join 후 해당 그룹 ID를 찾아서 설정
        final user = ref.read(currentUserProvider);
        final firestore = ref.read(firestoreProvider);
        if (user != null && firestore != null) {
          final memberships = await firestore
              .collection('memberships')
              .where('userId', isEqualTo: user.uid)
              .orderBy('joinedAt', descending: true)
              .limit(1)
              .get();
          if (memberships.docs.isNotEmpty) {
            final newGroupId =
                memberships.docs.first.data()['groupId'] as String;
            ref.read(selectedGroupIdProvider.notifier).state = newGroupId;
            ref.read(selectedGroupInitializedProvider.notifier).state = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_selected_group_id', newGroupId);
          }
        }
        await completeOnboarding(ref);
        // 성공 시 라우터 자동 이동
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 방어적 체크: 이미 그룹이 있는 사용자가 잘못 도착한 경우 자동 복구
    final memberships = ref.watch(userMembershipsProvider);
    if (!_autoRedirecting && !_isBusy && _inviteCode == null &&
        memberships.hasValue && (memberships.value?.isNotEmpty ?? false)) {
      _autoRedirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        debugPrint('[OnboardingScreen] ⚠️ User has ${memberships.value!.length} groups, auto-redirecting to /home');
        // 그룹 초기화 보장
        if (!ref.read(selectedGroupInitializedProvider)) {
          final groupId = memberships.value!.first.groupId;
          ref.read(selectedGroupIdProvider.notifier).state = groupId;
          ref.read(selectedGroupInitializedProvider.notifier).state = true;
        }
        if (mounted) context.go('/home');
      });
    }
    if (_autoRedirecting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 초대 코드가 생성된 경우 성공 화면 표시 (그룹 생성 모드에서)
    if (_inviteCode != null) {
      return _buildSuccessScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        // 선택 화면이 아닐 때는 뒤로가기 버튼 표시
        leading: _mode != 'selection'
            ? IconButton(
                icon: const Icon(Iconsax.arrow_left),
                onPressed: _isBusy ? null : _goToSelection,
              )
            : null,
        title: Text(_getTitle()),
        actions: [
          TextButton(
            onPressed: _isBusy
                ? null
                : () => ref.read(authServiceProvider).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isBusy,
              child: _mode == 'selection'
                  ? _buildSelectionView(context)
                  : _buildFormView(context),
            ),
            if (_isBusy && _mode == 'selection')
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_mode) {
      case 'create':
        return '새 그룹 만들기';
      case 'join':
        return '그룹 참여하기';
      default:
        return 'BABBA 시작하기';
    }
  }

  // 메인 선택 화면
  Widget _buildSelectionView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacingL),
          Text(
            '환영합니다!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '바쁜 일상을 어떻게 관리하실 건가요?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXXL),

          // 1. 혼자 시작하기 (강조)
          _SelectionCard(
            icon: Iconsax.user,
            title: '혼자 시작하기',
            subtitle: '나만의 공간에서 할 일과 일정을 관리합니다.',
            isPrimary: true,
            isLoading: _isLoading,
            onTap: _isLoading ? null : _startAlone,
          ),
          const SizedBox(height: AppTheme.spacingM),

          // 2. 새 그룹 만들기
          _SelectionCard(
            icon: Iconsax.add_circle,
            title: '새 그룹 만들기',
            subtitle: '가족, 친구, 동료와 함께 쓸 공간을 만듭니다.',
            onTap: _isBusy ? null : () => setState(() => _mode = 'create'),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // 3. 초대 코드로 참여
          _SelectionCard(
            icon: Iconsax.key,
            title: '초대 코드로 참여',
            subtitle: '이미 만들어진 그룹에 합류합니다.',
            onTap: _isBusy ? null : () => setState(() => _mode = 'join'),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppTheme.spacingL),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.errorLight),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // 입력 폼 화면 (생성/참여)
  Widget _buildFormView(BuildContext context) {
    final isCreate = _mode == 'create';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 정보 입력
            if (isCreate) ...[
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: '그룹 이름',
                  prefixIcon: Icon(Iconsax.home),
                  hintText: '예: 우리 가족, 스터디, 우정 멤버 등',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '그룹 이름을 입력해주세요';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(
                  labelText: '초대 코드',
                  prefixIcon: Icon(Iconsax.key),
                  hintText: '전달받은 6자리 코드',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '초대 코드를 입력해주세요';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: AppTheme.spacingM),

            // 내 이름
            TextFormField(
              controller: _memberNameController,
              decoration: const InputDecoration(
                labelText: '내 이름 (별명)',
                prefixIcon: Icon(Iconsax.user),
                hintText: '멤버들에게 보여질 이름',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 색상 선택
            Text('나의 색상', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '할일과 일정에서 나를 나타낼 색상을 선택하세요',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                AppColors.memberColors.length,
                (index) => _ColorOption(
                  color: AppColors.memberColors[index],
                  label: AppColors.memberColorNames[index],
                  isSelected: _selectedColorIndex == index,
                  onTap: _isBusy
                      ? null
                      : () => setState(() => _selectedColorIndex = index),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            // 에러 메시지
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.warning_2,
                      color: AppColors.errorLight,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.errorLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 버튼
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isCreate ? '그룹 만들기' : '입장하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 성공 화면 (그룹 생성 시 초대 코드 표시)
  Widget _buildSuccessScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isTransitioningToHome
              ? _buildTransitioningOverlay(context, isDark)
              : Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Iconsax.tick_circle5,
                        size: 80,
                        color: AppColors.successLight,
                      ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.elasticOut,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        '그룹이 생성되었습니다!',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        '아래 초대 코드를 멤버들에게 공유하세요',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                      const SizedBox(height: AppTheme.spacingXL),
                      Container(
                            padding: const EdgeInsets.all(AppTheme.spacingL),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              border: Border.all(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '초대 코드',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  _inviteCode!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: AppColors.primaryLight,
                                        letterSpacing: 4,
                                      ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 300.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: AppTheme.spacingXL),
                      ElevatedButton(
                        onPressed: _navigateToHome,
                        child: const Text('시작하기'),
                      ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// 홈으로 부드럽게 전환
  Future<void> _navigateToHome() async {
    setState(() {
      _isTransitioningToHome = true;
    });

    // 전환 애니메이션을 위한 짧은 지연
    await Future.delayed(const Duration(milliseconds: 300));
    await completeOnboarding(ref);

    // invalidate 제거 - 라우터가 자동으로 멤버십 감지하므로 불필요한 리스너 재트리거 방지

    if (mounted) {
      context.go('/home');
    }
  }

  /// 전환 중 오버레이
  Widget _buildTransitioningOverlay(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'BABBA 시작하기...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback? onTap;
  final bool isLoading;

  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isPrimary = false,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isPrimary ? 4 : 0,
      color: isPrimary
          ? Theme.of(context).colorScheme.primary
          : (isDark ? AppColors.surfaceDark : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.2)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isPrimary
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        icon,
                        color: isPrimary
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isPrimary ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                color: isPrimary ? Colors.white : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ColorOption({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(
                    Iconsax.tick_circle5,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
