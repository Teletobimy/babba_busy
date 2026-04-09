import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/module_provider.dart';
import '../../shared/providers/notification_settings_provider.dart';
import '../../shared/providers/update_provider.dart';
import '../../shared/providers/ai_feature_flag_provider.dart';
import '../../shared/widgets/member_avatar.dart';
import '../../shared/widgets/update_dialog.dart';
import '../auth/widgets/group_setup_dialog.dart';
import '../../shared/widgets/app_card.dart';
import '../../app/app.dart';
import '../../shared/models/todo_item.dart';
import '../../shared/providers/group_provider.dart';
import '../../shared/providers/stealth_provider.dart';
import '../../shared/providers/home_layout_provider.dart';
import '../../shared/providers/badge_provider.dart';
import '../../shared/services/analytics_service.dart';

String _getEventTypeDescription(TodoEventType type) {
  switch (type) {
    case TodoEventType.todo:
      return '개인적인 작은 할일';
    case TodoEventType.schedule:
      return '회의, 약속 등 일정';
    case TodoEventType.event:
      return '생일, 기념일 등 특별한 날';
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMember = ref.watch(smartCurrentMemberProvider);
    final currentGroup = ref.watch(smartCurrentFamilyProvider);
    final members = ref.watch(smartMembersProvider);
    final themeMode = ref.watch(themeModeProvider);
    final showAiDiagnostics = kDebugMode || currentMember?.role == 'admin';

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

              // 프로필 카드
              if (currentMember != null)
                AppCard(
                      child: Row(
                        children: [
                          MemberAvatar(member: currentMember, size: 60),
                          const SizedBox(width: AppTheme.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentMember.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentMember.email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (currentMember.statusMessage != null &&
                                    currentMember.statusMessage!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '"${currentMember.statusMessage!}"',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    currentMember.role == 'admin'
                                        ? '관리자'
                                        : '멤버',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      ref.watch(currentTitleProvider),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '🏅 ${ref.watch(earnedBadgeCountProvider)}개',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditProfileDialog(
                              context,
                              ref,
                              currentMember.name,
                              currentMember.color,
                            ),
                            icon: const Icon(Iconsax.edit_2),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 100.ms)
                    .slideY(begin: 0.1),

              // 그룹 정보 (프로필 바로 아래에 배치)
              if (currentGroup != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Iconsax.home_hashtag,
                                size: 20,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '참여 중인 그룹',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                child: const Icon(
                                  Iconsax.buildings,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            currentGroup.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () =>
                                              _showEditFamilyNameDialog(
                                                context,
                                                ref,
                                                currentGroup.id,
                                                currentGroup.name,
                                              ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Iconsax.edit_2,
                                              size: 14,
                                              color:
                                                  AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '구성원 ${members.length}명',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  currentGroup.inviteCode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: currentGroup.inviteCode,
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('초대 코드가 복사되었습니다'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Iconsax.copy, size: 16),
                                label: const Text(
                                  '복사',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '구성원 목록',
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: members
                                .map(
                                  (member) => MemberAvatar(
                                    member: member,
                                    size: 36,
                                    showName: true,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                          const Divider(),
                          const SizedBox(height: AppTheme.spacingM),
                          // 캘린더 공유 설정
                          Text(
                            '캘린더 공유 설정',
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            '이 그룹에 공유할 일정 타입을 선택하세요',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          ...TodoEventType.values.map((type) {
                            final currentMembership = ref.watch(
                              currentMembershipProvider,
                            );
                            final isShared =
                                currentMembership?.sharedEventTypes.contains(
                                  type.value,
                                ) ??
                                false;

                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: isShared,
                              onChanged: (value) async {
                                if (currentMembership == null) return;

                                final updatedTypes = List<String>.from(
                                  currentMembership.sharedEventTypes,
                                );
                                if (value == true) {
                                  if (!updatedTypes.contains(type.value)) {
                                    updatedTypes.add(type.value);
                                  }
                                } else {
                                  updatedTypes.remove(type.value);
                                }

                                try {
                                  await updateMembershipSharedEventTypes(
                                    ref,
                                    currentMembership.id,
                                    updatedTypes,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${type.label} 공유 설정이 업데이트되었습니다',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('설정 업데이트 실패: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              title: Text(type.label),
                              subtitle: Text(_getEventTypeDescription(type)),
                            );
                          }),
                          const SizedBox(height: AppTheme.spacingM),
                          // 다른 그룹 추가 버튼
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      const GroupSetupDialog(),
                                );
                              },
                              icon: const Icon(Iconsax.add_square, size: 18),
                              label: const Text('다른 그룹 추가하거나 참여하기'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          // 그룹 나가기 버튼
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showLeaveGroupDialog(
                                context,
                                ref,
                                currentGroup.id,
                                currentGroup.name,
                                members.length,
                              ),
                              icon: const Icon(Iconsax.logout, size: 18),
                              label: const Text('이 그룹에서 나가기'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                foregroundColor: AppColors.errorLight,
                                side: BorderSide(
                                  color: AppColors.errorLight.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 200.ms)
                    .slideY(begin: 0.1),
              ],
              const SizedBox(height: AppTheme.spacingL),

              // 도구 관리
              Text(
                '도구 관리',
                style: Theme.of(context).textTheme.titleMedium,
              ).animate().fadeIn(duration: 300.ms, delay: 250.ms),
              const SizedBox(height: AppTheme.spacingS),
              _ModuleManagementCard(),
              const SizedBox(height: AppTheme.spacingL),

              // 앱 설정
              Text(
                '앱 설정',
                style: Theme.of(context).textTheme.titleMedium,
              ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
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
                                ref.read(themeModeProvider.notifier).state =
                                    value;
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        // 스텔스 모드
                        _SettingsTile(
                          icon: Iconsax.eye_slash,
                          title: '스텔스 모드',
                          subtitle: '비공개 할일 숨기기',
                          trailing: Switch(
                            value: ref.watch(stealthModeProvider),
                            onChanged: (v) =>
                                ref.read(stealthModeProvider.notifier).state =
                                    v,
                          ),
                        ),
                        const Divider(height: 1),
                        // 홈 화면 커스터마이징
                        _SettingsTile(
                          icon: Iconsax.element_3,
                          title: '홈 화면 커스터마이징',
                          subtitle: '섹션 표시/숨기기',
                          onTap: () => _showHomeLayoutSheet(context, ref),
                        ),
                        const Divider(height: 1),
                        // 알림 설정
                        const _NotificationSettingsSection(),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 350.ms)
                  .slideY(begin: 0.1),
              const SizedBox(height: AppTheme.spacingL),

              if (showAiDiagnostics) ...[
                Text(
                  'AI 진단',
                  style: Theme.of(context).textTheme.titleMedium,
                ).animate().fadeIn(duration: 300.ms, delay: 360.ms),
                const SizedBox(height: AppTheme.spacingS),
                const _AiRolloutDiagnosticsCard()
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 380.ms)
                    .slideY(begin: 0.1),
                const SizedBox(height: AppTheme.spacingL),
              ],

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
                        // 버전 정보 및 업데이트 체크
                        const _VersionTile(),
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Iconsax.message_question,
                          title: '도움말',
                          onTap: () {},
                        ),
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
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
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
                        const Divider(height: 1),
                        _SettingsTile(
                          icon: Iconsax.trash,
                          title: '계정 삭제',
                          titleColor: AppColors.errorLight,
                          onTap: () => _showDeleteAccountDialog(context, ref),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 400.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: AppTheme.spacingXXL),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditFamilyNameDialog(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹 이름 수정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '그룹 이름',
            hintText: '예: 우리 팀, 친구들, 개인 등',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      try {
        await ref.read(authServiceProvider).updateFamilyName(familyId, result);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('그룹 이름이 수정되었습니다')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentColor,
  ) async {
    final nameController = TextEditingController(text: currentName);
    final currentMember = ref.read(smartCurrentMemberProvider);
    final statusController = TextEditingController(
      text: currentMember?.statusMessage ?? '',
    );
    String selectedColor = currentColor;

    // 현재 멤버의 아바타 정보
    String avatarType = currentMember?.avatarType ?? 'color';
    String? avatarEmoji = currentMember?.avatarEmoji;

    const emojiOptions = [
      '😀',
      '😎',
      '🥰',
      '🤗',
      '😇',
      '🦊',
      '🐱',
      '🐶',
      '🌸',
      '⭐',
      '🎯',
      '🔥',
      '💎',
      '🌈',
      '🎨',
      '🎵',
    ];

    // 미리 정의된 색상 목록
    const profileColors = [
      '#FFCBA4', // Peach
      '#FF7F7F', // Coral
      '#FFB347', // Orange
      '#FFE066', // Yellow
      '#90EE90', // Light Green
      '#87CEEB', // Sky Blue
      '#9B59B6', // Purple
      '#E6B0AA', // Rose
    ];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('프로필 편집'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '이 그룹에서 사용할 이름',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: statusController,
                  decoration: const InputDecoration(
                    labelText: '상태 메시지',
                    hintText: '지금 기분이나 하고 있는 일',
                    counterText: '',
                  ),
                  maxLength: 30,
                  maxLines: 1,
                ),
                const SizedBox(height: AppTheme.spacingM),
                // 아바타 타입 선택
                Text('아바타 스타일', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppTheme.spacingS),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'color', label: Text('색상')),
                    ButtonSegment(value: 'emoji', label: Text('이모지')),
                  ],
                  selected: {avatarType},
                  onSelectionChanged: (s) => setState(() {
                    avatarType = s.first;
                    if (avatarType == 'emoji' && avatarEmoji == null) {
                      avatarEmoji = '😀';
                    }
                  }),
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (avatarType == 'emoji') ...[
                  Text('이모지 선택', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppTheme.spacingS),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: emojiOptions.map((emoji) {
                      final isSelected = avatarEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setState(() => avatarEmoji = emoji),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primaryLight,
                                    width: 3,
                                  )
                                : Border.all(
                                    color: Colors.grey.withValues(alpha: 0.3),
                                  ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
                Text('프로필 색상', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppTheme.spacingS),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profileColors.map((color) {
                    final isSelected =
                        selectedColor.toUpperCase() == color.toUpperCase();
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(color.replaceFirst('#', '0xFF')),
                          ),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primaryLight,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text.trim(),
                'color': selectedColor,
                'avatarType': avatarType,
                'avatarEmoji': avatarEmoji ?? '',
                'statusMessage': statusController.text.trim(),
              }),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    statusController.dispose();

    if (result != null && result['name']!.isNotEmpty) {
      final membership = ref.read(currentMembershipProvider);
      if (membership == null) return;

      final nameChanged = result['name'] != currentName;
      final colorChanged =
          result['color']!.toUpperCase() != currentColor.toUpperCase();
      final avatarTypeChanged =
          result['avatarType'] != (currentMember?.avatarType ?? 'color');
      final avatarEmojiChanged =
          result['avatarEmoji'] != (currentMember?.avatarEmoji ?? '');
      final statusChanged =
          result['statusMessage'] != (currentMember?.statusMessage ?? '');

      if (!nameChanged &&
          !colorChanged &&
          !avatarTypeChanged &&
          !avatarEmojiChanged &&
          !statusChanged) {
        return;
      }

      try {
        await updateMembershipProfile(
          ref,
          membership.id,
          name: nameChanged ? result['name'] : null,
          color: colorChanged ? result['color'] : null,
          avatarType: avatarTypeChanged ? result['avatarType'] : null,
          avatarEmoji: avatarEmojiChanged ? result['avatarEmoji'] : null,
          statusMessage: statusChanged ? result['statusMessage'] : null,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('프로필이 수정되었습니다')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        }
      }
    }
  }

  void _showHomeLayoutSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final layout = ref.watch(homeLayoutProvider);
            return Column(
              children: [
                // 핸들
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '홈 화면 섹션',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(homeLayoutProvider.notifier).reset(),
                        child: const Text('초기화'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scrollController,
                    itemCount: layout.order.length,
                    onReorder: (oldIndex, newIndex) => ref
                        .read(homeLayoutProvider.notifier)
                        .reorder(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final section = layout.order[index];
                      final visible = layout.isVisible(section);
                      return ListTile(
                        key: ValueKey(section),
                        leading: const Icon(Iconsax.menu),
                        title: Text(section.label),
                        trailing: Switch(
                          value: visible,
                          onChanged: (_) => ref
                              .read(homeLayoutProvider.notifier)
                              .toggleSection(section),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showLeaveGroupDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String groupName,
    int memberCount,
  ) async {
    final isLastMember = memberCount <= 1;
    final warningMessage = isLastMember
        ? '마지막 멤버이므로 나가면 그룹 "$groupName"이(가) 삭제됩니다.\n\n정말 나가시겠습니까?'
        : '그룹 "$groupName"에서 나가시겠습니까?\n\n그룹의 데이터는 남아있으며 다시 초대받으면 참여할 수 있습니다.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isLastMember ? Iconsax.warning_2 : Iconsax.logout,
              color: AppColors.errorLight,
            ),
            const SizedBox(width: 8),
            const Text('그룹 나가기'),
          ],
        ),
        content: Text(warningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: Text(isLastMember ? '나가고 삭제' : '나가기'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 로딩 다이얼로그 표시
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('처리 중...'),
            ],
          ),
        ),
      );
    }

    try {
      final result = await leaveGroupAndSwitch(ref, groupId);

      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        final wasGroupDeleted = result['wasGroupDeleted'] == true;
        final hasRemainingGroups = result['hasRemainingGroups'] == true;

        if (context.mounted) {
          String message;
          if (wasGroupDeleted) {
            message = '그룹 "$groupName"이(가) 삭제되었습니다.';
          } else {
            message = '그룹 "$groupName"에서 나왔습니다.';
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));

          // 남은 그룹이 없으면 온보딩으로 이동
          if (!hasRemainingGroups) {
            // GoRouter가 자동으로 리다이렉트 처리
          }
        }
      } else {
        throw Exception(result['error'] ?? '알 수 없는 오류');
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('그룹 나가기 실패: $e'),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // 1단계: 경고 다이얼로그
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Iconsax.warning_2, color: AppColors.errorLight),
            const SizedBox(width: 8),
            const Text('계정 삭제'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 계정을 삭제하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('삭제되는 데이터:'),
            SizedBox(height: 4),
            Text('• 모든 할일, 일정, 메모'),
            Text('• 업로드한 사진과 앨범'),
            Text('• 가계부 기록'),
            Text('• 그룹 멤버십'),
            Text('• AI 분석 데이터'),
            SizedBox(height: 12),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: const Text('계속'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !context.mounted) return;

    // 2단계: 재인증 및 최종 확인
    final user = ref.read(currentUserProvider);
    final isGoogleUser =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

    bool reauthenticated = false;

    if (isGoogleUser) {
      // Google 사용자: Google 재인증
      final confirmReauth = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('본인 확인'),
          content: const Text('계정 삭제를 진행하려면 Google 계정으로 다시 로그인해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Google로 확인'),
            ),
          ],
        ),
      );

      if (confirmReauth == true && context.mounted) {
        reauthenticated = await ref
            .read(authServiceProvider)
            .reauthenticateWithGoogle();
      }
    } else {
      // 이메일 사용자: 비밀번호 입력
      final passwordController = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('본인 확인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('계정 삭제를 진행하려면 비밀번호를 입력해주세요.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      passwordController.dispose();

      if (password != null && password.isNotEmpty && context.mounted) {
        reauthenticated = await ref
            .read(authServiceProvider)
            .reauthenticateWithPassword(password);
      }
    }

    if (!reauthenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('본인 확인에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 3단계: 최종 확인
    if (!context.mounted) return;
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Iconsax.danger, color: AppColors.errorLight),
            const SizedBox(width: 8),
            const Text('최종 확인'),
          ],
        ),
        content: const Text('계정을 영구적으로 삭제합니다.\n\n삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorLight,
              foregroundColor: Colors.white,
            ),
            child: const Text('계정 삭제'),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !context.mounted) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('계정을 삭제하는 중...\n잠시만 기다려주세요.')),
          ],
        ),
      ),
    );

    try {
      await ref.read(authServiceProvider).deleteAccount();

      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('계정이 삭제되었습니다.')));
      }
      // 로그인 화면으로 이동 (GoRouter가 자동 처리)
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정 삭제 실패: $e'),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
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
              color:
                  titleColor ??
                  (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: titleColor, fontSize: 15),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
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

/// 모듈 관리 카드
class _ModuleManagementCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(enabledModulesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                Icon(Iconsax.box_1, size: 20, color: const Color(0xFF5B8DEF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '도구 탭에서 사용할 기능을 선택하세요',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...AppModule.values.map((module) {
            final info = modules[module];
            final isEnabled = info?.isEnabled ?? true;

            return _ModuleTile(
              module: module,
              isEnabled: isEnabled,
              onChanged: (value) {
                ref
                    .read(enabledModulesProvider.notifier)
                    .setModuleEnabled(module, value);
              },
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 275.ms).slideY(begin: 0.1);
  }
}

class _ModuleTile extends StatelessWidget {
  final AppModule module;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ModuleTile({
    required this.module,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getModuleColor(module).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getModuleIcon(module),
              size: 18,
              color: _getModuleColor(module),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isEnabled
                        ? null
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                ),
                Text(
                  _getModuleDescription(module),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeTrackColor: _getModuleColor(module),
          ),
        ],
      ),
    );
  }

  IconData _getModuleIcon(AppModule module) {
    switch (module) {
      case AppModule.memo:
        return Iconsax.note_1;
      case AppModule.album:
        return Iconsax.gallery;
      case AppModule.budget:
        return Iconsax.wallet_3;
      case AppModule.people:
        return Iconsax.people;
      case AppModule.chat:
        return Iconsax.message;
      case AppModule.community:
        return Iconsax.hashtag;
      case AppModule.business:
        return Iconsax.briefcase;
      case AppModule.psychology:
        return Iconsax.heart;
    }
  }

  Color _getModuleColor(AppModule module) {
    switch (module) {
      case AppModule.memo:
        return AppColors.memoColor;
      case AppModule.album:
        return AppColors.memoryColor;
      case AppModule.budget:
        return AppColors.budgetColor;
      case AppModule.people:
        return AppColors.peopleColor;
      case AppModule.chat:
        return AppColors.chatColor;
      case AppModule.community:
        return AppColors.communityColor;
      case AppModule.business:
        return AppColors.coral[500]!;
      case AppModule.psychology:
        return AppColors.lavender[500]!;
    }
  }

  String _getModuleDescription(AppModule module) {
    switch (module) {
      case AppModule.memo:
        return '메모 및 아이디어 기록';
      case AppModule.album:
        return '사진 앨범 공유';
      case AppModule.budget:
        return '가계부 관리';
      case AppModule.people:
        return '인맥 정보 관리';
      case AppModule.chat:
        return '그룹 대화방';
      case AppModule.community:
        return '테마 기반 공개 커뮤니티';
      case AppModule.business:
        return 'AI 멀티에이전트 사업 검토';
      case AppModule.psychology:
        return '7종 심리검사';
    }
  }
}

/// 알림 설정 섹션
class _NotificationSettingsSection extends ConsumerWidget {
  const _NotificationSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return settingsAsync.when(
      data: (settings) => Column(
        children: [
          // 전체 알림 토글
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingM,
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.notification,
                    size: 22,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('알림', style: TextStyle(fontSize: 15)),
                        Text(
                          settings.enabled ? '알림이 켜져 있습니다' : '알림이 꺼져 있습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.enabled,
                    onChanged: (value) {
                      ref
                          .read(notificationSettingsServiceProvider)
                          .toggleEnabled(value);
                    },
                    activeTrackColor: AppColors.primaryLight,
                  ),
                ],
              ),
            ),
          ),
          // 세부 알림 설정 (전체 알림이 켜진 경우에만)
          if (settings.enabled) ...[
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Column(
                children: [
                  const Divider(height: 1),
                  _NotificationSubTile(
                    icon: Iconsax.message,
                    title: '채팅 알림',
                    subtitle: '새 채팅 메시지 수신 시 알림',
                    value: settings.chatEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationSettingsServiceProvider)
                          .toggleChat(value);
                    },
                  ),
                  const Divider(height: 1),
                  _NotificationSubTile(
                    icon: Iconsax.task_square,
                    title: '할일 알림',
                    subtitle: '할일 마감, 변경 알림',
                    value: settings.todoEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationSettingsServiceProvider)
                          .toggleTodo(value);
                    },
                  ),
                  const Divider(height: 1),
                  _NotificationSubTile(
                    icon: Iconsax.calendar,
                    title: '일정 알림',
                    subtitle: '일정 시작 전 알림',
                    value: settings.eventEnabled,
                    onChanged: (value) {
                      ref
                          .read(notificationSettingsServiceProvider)
                          .toggleEvent(value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _SettingsTile(
        icon: Iconsax.notification,
        title: '알림',
        trailing: Text('로드 실패'),
      ),
    );
  }
}

/// 알림 세부 설정 타일
class _NotificationSubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }
}

/// 버전 정보 및 업데이트 체크 타일
class _VersionTile extends ConsumerStatefulWidget {
  const _VersionTile();

  @override
  ConsumerState<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends ConsumerState<_VersionTile> {
  String _version = '';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isChecking = true);

    try {
      final updateInfo = await ref.read(forceUpdateCheckProvider(true).future);

      if (!mounted) return;

      if (updateInfo != null && updateInfo.updateAvailable) {
        await UpdateDialog.show(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재 최신 버전입니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업데이트 확인에 실패했습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: _isChecking ? null : _checkForUpdate,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingM,
        ),
        child: Row(
          children: [
            Icon(
              Iconsax.info_circle,
              size: 22,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('앱 버전', style: TextStyle(fontSize: 15)),
                  Text(
                    _version.isEmpty ? '로딩 중...' : 'v$_version',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (_isChecking)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: _checkForUpdate,
                child: Text(
                  '업데이트 확인',
                  style: TextStyle(fontSize: 13, color: AppColors.coral),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _AiRolloutHealth { healthy, caution, blocked }

class _AiRolloutDiagnosticsCard extends ConsumerWidget {
  const _AiRolloutDiagnosticsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(babbaAiFeatureFlagsProvider);
    final analytics = AnalyticsService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return ValueListenableBuilder<List<AnalyticsEventRecord>>(
      valueListenable: analytics.recentEventsListenable,
      builder: (context, records, _) {
        final aiEvents = records
            .where((record) => record.name.startsWith('ai_'))
            .toList()
            .reversed
            .toList();
        final failureCount = aiEvents.where(_isFailureEvent).length;
        final fallbackCount = aiEvents
            .where(
              (record) =>
                  record.name == 'ai_summary_rendered' &&
                  record.parameters['fallback_used'] == true,
            )
            .length;
        final deniedCount = aiEvents
            .where(
              (record) =>
                  record.name == 'ai_consent_outcome' &&
                  record.parameters['outcome'] != 'approved',
            )
            .length;
        final approvedCount = aiEvents
            .where(
              (record) =>
                  record.name == 'ai_consent_outcome' &&
                  record.parameters['outcome'] == 'approved',
            )
            .length;

        final health = !flags.hasRemoteAiApi || failureCount > 0
            ? _AiRolloutHealth.blocked
            : fallbackCount > 0
            ? _AiRolloutHealth.caution
            : _AiRolloutHealth.healthy;
        final healthColor = switch (health) {
          _AiRolloutHealth.healthy => AppColors.successLight,
          _AiRolloutHealth.caution => Colors.orange,
          _AiRolloutHealth.blocked => AppColors.errorLight,
        };
        final healthLabel = switch (health) {
          _AiRolloutHealth.healthy => '정상',
          _AiRolloutHealth.caution => '주의',
          _AiRolloutHealth.blocked => '차단',
        };
        final stopReasons = <String>[
          if (!flags.hasRemoteAiApi) 'AI API 미연결',
          if (failureCount > 0) '실패 이벤트 $failureCount건',
          if (flags.hasRemoteAiApi && failureCount == 0 && fallbackCount > 0)
            'fallback 발생 $fallbackCount건',
        ];

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: healthColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      health == _AiRolloutHealth.healthy
                          ? Iconsax.shield_tick
                          : health == _AiRolloutHealth.caution
                          ? Iconsax.warning_2
                          : Iconsax.close_circle,
                      color: healthColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Rollout Diagnostics',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stopReasons.isEmpty
                              ? '현재 세션 기준 canary stop-condition이 감지되지 않았습니다.'
                              : stopReasons.join(' • '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: mutedColor, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: analytics.clearRecentEvents,
                    icon: const Icon(Iconsax.trash, size: 16),
                    label: const Text('지우기'),
                    style: TextButton.styleFrom(
                      foregroundColor: mutedColor,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AiDiagChip(
                    label: '상태',
                    value: healthLabel,
                    color: healthColor,
                  ),
                  _AiDiagChip(
                    label: 'AI API',
                    value: flags.hasRemoteAiApi ? '연결됨' : '미연결',
                    color: flags.hasRemoteAiApi
                        ? AppColors.successLight
                        : AppColors.errorLight,
                  ),
                  _AiDiagChip(
                    label: '실패',
                    value: '$failureCount',
                    color: failureCount > 0
                        ? AppColors.errorLight
                        : AppColors.successLight,
                  ),
                  _AiDiagChip(
                    label: 'Fallback',
                    value: '$fallbackCount',
                    color: fallbackCount > 0
                        ? Colors.orange
                        : AppColors.successLight,
                  ),
                  _AiDiagChip(
                    label: '승인',
                    value: '$approvedCount',
                    color: AppColors.primaryLight,
                  ),
                  _AiDiagChip(
                    label: '비승인',
                    value: '$deniedCount',
                    color: AppColors.textSecondaryLight,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Capability 상태',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BabbaAiCapability.values
                    .map(
                      (capability) => _AiCapabilityPill(
                        label: _capabilityLabel(capability),
                        enabled: flags.isEnabled(capability),
                        disabledReason: flags.disabledReasonFor(capability),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Text(
                    '최근 AI 이벤트',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${aiEvents.length}개',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              if (aiEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight)
                            .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    '아직 수집된 AI 이벤트가 없습니다. 요약 카드 확장이나 AI 액션을 한 번 실행해 보세요.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                )
              else
                ...aiEvents
                    .take(8)
                    .map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AiEventRow(record: record),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  bool _isFailureEvent(AnalyticsEventRecord record) {
    if (record.name == 'ai_preview_failed' ||
        record.name == 'ai_summary_failed') {
      return true;
    }
    if (record.name != 'ai_action_result') {
      return false;
    }
    final outcome = (record.parameters['outcome'] ?? '').toString();
    return outcome == 'failed';
  }

  String _capabilityLabel(BabbaAiCapability capability) {
    return switch (capability) {
      BabbaAiCapability.homeSummary => '홈 요약',
      BabbaAiCapability.familyChatSummary => '가족 채팅 요약',
      BabbaAiCapability.memoSummary => '메모 요약',
      BabbaAiCapability.todoActions => '할 일 액션',
      BabbaAiCapability.calendarActions => '일정 액션',
      BabbaAiCapability.noteActions => '메모 액션',
      BabbaAiCapability.reminderActions => '리마인더 액션',
    };
  }
}

class _AiDiagChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AiDiagChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AiCapabilityPill extends StatelessWidget {
  final String label;
  final bool enabled;
  final String? disabledReason;

  const _AiCapabilityPill({
    required this.label,
    required this.enabled,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.successLight
        : AppColors.textSecondaryLight;

    return Tooltip(
      message: enabled ? '$label 활성화' : (disabledReason ?? '$label 비활성화'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          '$label ${enabled ? 'ON' : 'OFF'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AiEventRow extends StatelessWidget {
  final AnalyticsEventRecord record;

  const _AiEventRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final tool = (record.parameters['tool_requested'] ?? '').toString();
    final source = (record.parameters['trigger_source'] ?? '').toString();
    final outcome = (record.parameters['outcome'] ?? '').toString();
    final statusColor = outcome == 'failed'
        ? AppColors.errorLight
        : outcome == 'approved'
        ? AppColors.successLight
        : outcome == 'denied' || outcome == 'dismissed'
        ? Colors.orange
        : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _formatTime(record.timestamp),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (tool.isNotEmpty) 'tool=$tool',
              if (source.isNotEmpty) 'source=$source',
              if (outcome.isNotEmpty) 'outcome=$outcome',
            ].join('  '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          if (record.parameters.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _summarizeParameters(record.parameters),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: mutedColor, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _summarizeParameters(Map<String, dynamic> parameters) {
    final entries = parameters.entries
        .where(
          (entry) => !{
            'tool_requested',
            'trigger_source',
            'outcome',
          }.contains(entry.key),
        )
        .take(4)
        .map((entry) => '${entry.key}=${entry.value}')
        .toList();
    return entries.join('  ');
  }
}
