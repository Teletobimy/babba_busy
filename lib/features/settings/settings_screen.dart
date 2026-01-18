import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/demo_provider.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/widgets/app_card.dart';
import '../../app/app.dart';
import '../../app/router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(demoModeProvider);
    
    final currentMember = demoMode 
        ? ref.watch(demoMembersProvider).first
        : ref.watch(currentMemberProvider).value;
    final currentFamily = demoMode 
        ? ref.watch(demoFamilyProvider)
        : ref.watch(currentFamilyProvider).value;
    final members = demoMode 
        ? ref.watch(demoMembersProvider)
        : (ref.watch(familyMembersProvider).value ?? []);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '설정',
                  style: Theme.of(context).textTheme.headlineSmall,
                ).animate().fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: AppTheme.spacingL),

              // 데모 모드 표시
              if (demoMode)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: AppColors.budgetColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppColors.budgetColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, color: AppColors.budgetColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '데모 모드로 실행 중입니다. Firebase 연동 후 실제 데이터를 사용하세요.',
                          style: TextStyle(
                            color: AppColors.budgetColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),

              // 프로필 카드
              if (currentMember != null)
                AppCard(
                  child: Row(
                    children: [
                      MemberAvatar(
                        member: currentMember,
                        size: 60,
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMember.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentMember.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentMember.role == 'admin' ? '관리자' : '멤버',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // 프로필 편집
                        },
                        icon: const Icon(Iconsax.edit_2),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1),
              const SizedBox(height: AppTheme.spacingL),

              // 가족 정보
              if (currentFamily != null) ...[
                Text(
                  '가족',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(duration: 300.ms, delay: 150.ms),
                const SizedBox(height: AppTheme.spacingS),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Icon(
                              Iconsax.home_hashtag5,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentFamily.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '구성원 ${members.length}명',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      const Divider(),
                      const SizedBox(height: AppTheme.spacingM),
                      // 초대 코드
                      Row(
                        children: [
                          const Icon(Iconsax.key, size: 18),
                          const SizedBox(width: 8),
                          const Text('초대 코드: '),
                          Text(
                            currentFamily.inviteCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              // 복사
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('초대 코드가 복사되었습니다')),
                              );
                            },
                            icon: const Icon(Iconsax.copy, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      // 구성원 목록
                      Text(
                        '구성원',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: members
                            .map((member) => MemberAvatar(
                                  member: member,
                                  size: 40,
                                  showName: true,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideY(begin: 0.1),
              ],
              const SizedBox(height: AppTheme.spacingL),

              // 앱 설정
              Text(
                '앱 설정',
                style: Theme.of(context).textTheme.titleMedium,
              ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
              const SizedBox(height: AppTheme.spacingS),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // 테마 설정
                    _SettingsTile(
                      icon: Iconsax.moon,
                      title: '테마',
                      trailing: DropdownButton<ThemeMode>(
                        value: themeMode,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('시스템 설정'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('라이트'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('다크'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(themeModeProvider.notifier).state = value;
                          }
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    // 알림 설정
                    _SettingsTile(
                      icon: Iconsax.notification,
                      title: '알림',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // 알림 설정
                        },
                        activeTrackColor: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.1),
              const SizedBox(height: AppTheme.spacingL),

              // 기타
              Text(
                '기타',
                style: Theme.of(context).textTheme.titleMedium,
              ).animate().fadeIn(duration: 300.ms, delay: 350.ms),
              const SizedBox(height: AppTheme.spacingS),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Iconsax.info_circle,
                      title: '앱 정보',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Family Hub',
                          applicationVersion: '1.0.0',
                          applicationLegalese: '© 2024 Family Hub',
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Iconsax.message_question,
                      title: '도움말',
                      onTap: () {},
                    ),
                    if (!demoMode) ...[
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Iconsax.logout,
                        title: '로그아웃',
                        titleColor: AppColors.errorLight,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('로그아웃'),
                              content: const Text('로그아웃 하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('로그아웃'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(authServiceProvider).signOut();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: AppTheme.spacingXXL),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: titleColor ??
                  (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
          ],
        ),
      ),
    );
  }
}
