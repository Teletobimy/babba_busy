import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  bool _isCreateMode = true;
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _memberNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  int _selectedColorIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _inviteCode;

  @override
  void dispose() {
    _familyNameController.dispose();
    _memberNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final color = AppColors.memberColors[_selectedColorIndex];
      final colorHex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

      if (_isCreateMode) {
        final code = await authService.createFamily(
          _familyNameController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );
        setState(() => _inviteCode = code);
      } else {
        await authService.joinFamily(
          _inviteCodeController.text.trim(),
          _memberNameController.text.trim(),
          colorHex,
        );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 초대 코드가 생성된 경우 성공 화면 표시
    if (_inviteCode != null) {
      return _buildSuccessScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 설정'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 모드 선택 탭
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: '가족 만들기',
                          isSelected: _isCreateMode,
                          onTap: () => setState(() => _isCreateMode = true),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          label: '가족 참여하기',
                          isSelected: !_isCreateMode,
                          onTap: () => setState(() => _isCreateMode = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // 에러 메시지
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.warning_2, color: AppColors.errorLight, size: 20),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppColors.errorLight, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],

                // 가족 이름 또는 초대 코드
                if (_isCreateMode) ...[
                  TextFormField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(
                      labelText: '가족 이름',
                      prefixIcon: Icon(Iconsax.home),
                      hintText: '예: 행복한 우리집',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '가족 이름을 입력해주세요';
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
                      hintText: '예: ABC123',
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
                    hintText: '가족들에게 보여질 이름',
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
                Text(
                  '나의 색상',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
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
                      onTap: () => setState(() => _selectedColorIndex = index),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // 제출 버튼
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
                        : Text(_isCreateMode ? '가족 만들기' : '가족 참여하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Iconsax.tick_circle5,
                size: 80,
                color: AppColors.successLight,
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                '가족이 생성되었습니다!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                '아래 초대 코드를 가족들에게 공유하세요',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXL),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
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
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.primaryLight,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: () {
                  // 라우터가 자동으로 홈으로 리다이렉트
                  ref.invalidate(currentMemberProvider);
                },
                child: const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

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
                ? const Icon(Iconsax.tick_circle5, color: Colors.white, size: 24)
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
