import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/person.dart';

const Color peopleColor = Color(0xFF5B8DEF);

class PersonDetailSheet extends ConsumerWidget {
  final Person person;

  const PersonDetailSheet({
    super.key,
    required this.person,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLarge),
            ),
          ),
          child: Column(
            children: [
              // 핸들
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 콘텐츠
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로필 헤더
                      _buildProfileHeader(context),
                      const SizedBox(height: AppTheme.spacingL),

                      // 빠른 액션 버튼
                      _buildQuickActions(context),
                      const SizedBox(height: AppTheme.spacingL),

                      // 기본 정보
                      _buildSection(
                        context,
                        '기본 정보',
                        [
                          if (person.birthday != null)
                            _InfoRow(
                              icon: Iconsax.cake,
                              label: '생일',
                              value:
                                  '${DateFormat('yyyy년 M월 d일').format(person.birthday!)} (만 ${person.age}세)',
                              trailing: person.daysUntilBirthday != null
                                  ? Text(
                                      person.daysUntilBirthday == 0
                                          ? '오늘!'
                                          : 'D-${person.daysUntilBirthday}',
                                      style: TextStyle(
                                        color: (person.daysUntilBirthday ?? 999) <= 7
                                            ? const Color(0xFFFF6B6B)
                                            : peopleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                          if (person.mbti != null)
                            _InfoRow(
                              icon: Iconsax.personalcard,
                              label: 'MBTI',
                              value: person.mbti!,
                            ),
                          if (person.relationship != null)
                            _InfoRow(
                              icon: Iconsax.people,
                              label: '관계',
                              value: PersonRelationship.getLabel(
                                  person.relationship!),
                            ),
                          if (person.company != null)
                            _InfoRow(
                              icon: Iconsax.building,
                              label: '회사/학교',
                              value: person.company!,
                            ),
                        ],
                      ),

                      // 연락처
                      if (person.phone != null ||
                          person.email != null ||
                          person.address != null)
                        _buildSection(
                          context,
                          '연락처',
                          [
                            if (person.phone != null)
                              _InfoRow(
                                icon: Iconsax.call,
                                label: '전화',
                                value: person.phone!,
                                onTap: () => _copyToClipboard(
                                    context, '전화번호', person.phone!),
                              ),
                            if (person.email != null)
                              _InfoRow(
                                icon: Iconsax.sms,
                                label: '이메일',
                                value: person.email!,
                                onTap: () => _copyToClipboard(
                                    context, '이메일', person.email!),
                              ),
                            if (person.address != null)
                              _InfoRow(
                                icon: Iconsax.location,
                                label: '주소',
                                value: person.address!,
                                onTap: () => _copyToClipboard(
                                    context, '주소', person.address!),
                              ),
                          ],
                        ),

                      // 성격/특징
                      if (person.personality != null)
                        _buildSection(
                          context,
                          '성격/특징',
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.backgroundDark
                                    : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                              ),
                              child: Text(
                                person.personality!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),

                      // 메모
                      if (person.note != null)
                        _buildSection(
                          context,
                          '메모',
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.backgroundDark
                                    : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                              ),
                              child: Text(
                                person.note!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),

                      // 커스텀 필드
                      if (person.customFields.isNotEmpty)
                        _buildSection(
                          context,
                          '추가 정보',
                          person.customFields.entries.map((entry) {
                            return _InfoRow(
                              icon: Iconsax.document,
                              label: entry.key,
                              value: entry.value,
                            );
                          }).toList(),
                        ),

                      // 이벤트/기념일
                      if (person.events.isNotEmpty)
                        _buildSection(
                          context,
                          '기념일',
                          person.events.map((event) {
                            return _InfoRow(
                              icon: Iconsax.calendar_1,
                              label: event.title,
                              value: DateFormat('M월 d일').format(event.date),
                              trailing: event.isYearly
                                  ? const Icon(Iconsax.repeat,
                                      size: 16, color: Colors.grey)
                                  : null,
                            );
                          }).toList(),
                        ),

                      // 태그
                      if (person.tags.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingL),
                        Text(
                          '태그',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: person.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: peopleColor.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusFull),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: peopleColor,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // 아바타
        CircleAvatar(
          radius: 40,
          backgroundColor:
              _getRelationshipColor(person.relationship).withValues(alpha: 0.2),
          backgroundImage: person.profilePhotoUrl != null
              ? NetworkImage(person.profilePhotoUrl!)
              : null,
          child: person.profilePhotoUrl == null
              ? Text(
                  person.name[0],
                  style: TextStyle(
                    color: _getRelationshipColor(person.relationship),
                    fontWeight: FontWeight.w600,
                    fontSize: 32,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      person.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (person.mbti != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: peopleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        person.mbti!,
                        style: TextStyle(
                          color: peopleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (person.relationship != null || person.company != null)
                Text(
                  [
                    if (person.relationship != null)
                      PersonRelationship.getLabel(person.relationship!),
                    if (person.company != null) person.company,
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
            ],
          ),
        ),
        // 편집 버튼
        IconButton(
          onPressed: () {
            // TODO: 편집 기능
          },
          icon: const Icon(Iconsax.edit_2),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (person.phone != null)
          _QuickActionButton(
            icon: Iconsax.call,
            label: '전화',
            color: const Color(0xFF4ECDC4),
            onTap: () {
              // TODO: 전화 걸기
            },
          ),
        if (person.phone != null)
          _QuickActionButton(
            icon: Iconsax.message,
            label: '문자',
            color: const Color(0xFF7C4DFF),
            onTap: () {
              // TODO: 문자 보내기
            },
          ),
        if (person.email != null)
          _QuickActionButton(
            icon: Iconsax.sms,
            label: '이메일',
            color: const Color(0xFFFFA726),
            onTap: () {
              // TODO: 이메일 보내기
            },
          ),
        _QuickActionButton(
          icon: Iconsax.calendar_add,
          label: '일정추가',
          color: peopleColor,
          onTap: () {
            // TODO: 캘린더에 일정 추가
          },
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacingL),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppTheme.spacingS),
        ...children,
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label가 복사되었습니다'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Color _getRelationshipColor(String? relationship) {
    switch (relationship) {
      case PersonRelationship.family:
        return const Color(0xFFFF6B6B);
      case PersonRelationship.friend:
        return const Color(0xFF4ECDC4);
      case PersonRelationship.colleague:
        return const Color(0xFFFFA726);
      case PersonRelationship.school:
        return const Color(0xFF7C4DFF);
      case PersonRelationship.neighbor:
        return const Color(0xFF66BB6A);
      default:
        return peopleColor;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null)
              Icon(
                Iconsax.copy,
                size: 16,
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
