import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/person.dart';
import '../../../shared/providers/people_provider.dart';
import '../../../shared/utils/people_care_assistant.dart';
import 'add_person_sheet.dart';

const Color peopleColor = Color(0xFF5B8DEF);

class PersonDetailSheet extends ConsumerWidget {
  final Person person;

  const PersonDetailSheet({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final careTarget =
        ref.watch(personCareTargetProvider(person.id)) ??
        PeopleCareTarget(
          person: person,
          score: calculateCarePriorityScore(person),
          reasons: buildCareReasons(person),
          giftSuggestions: recommendGiftIdeas(person, max: 4),
        );

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
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingM,
                ),
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
                      _buildProfileHeader(context, ref),
                      const SizedBox(height: AppTheme.spacingL),

                      // 빠른 액션 버튼
                      _buildQuickActions(context),
                      const SizedBox(height: AppTheme.spacingL),

                      // AI 챙김 요약
                      _buildAssistantSection(context, careTarget),

                      // 기본 정보
                      _buildSection(context, '기본 정보', [
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
                                      color:
                                          (person.daysUntilBirthday ?? 999) <= 7
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
                              person.relationship!,
                            ),
                          ),
                        if (person.company != null)
                          _InfoRow(
                            icon: Iconsax.building,
                            label: '회사/학교',
                            value: person.company!,
                          ),
                      ]),

                      // 연락처
                      if (person.phone != null ||
                          person.email != null ||
                          person.address != null)
                        _buildSection(context, '연락처', [
                          if (person.phone != null)
                            _InfoRow(
                              icon: Iconsax.call,
                              label: '전화',
                              value: person.phone!,
                              onTap: () => _copyToClipboard(
                                context,
                                '전화번호',
                                person.phone!,
                              ),
                            ),
                          if (person.email != null)
                            _InfoRow(
                              icon: Iconsax.sms,
                              label: '이메일',
                              value: person.email!,
                              onTap: () => _copyToClipboard(
                                context,
                                '이메일',
                                person.email!,
                              ),
                            ),
                          if (person.address != null)
                            _InfoRow(
                              icon: Iconsax.location,
                              label: '주소',
                              value: person.address!,
                              onTap: () => _copyToClipboard(
                                context,
                                '주소',
                                person.address!,
                              ),
                            ),
                        ]),

                      // 성격/특징
                      if (person.personality != null)
                        _buildSection(context, '성격/특징', [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Text(
                              person.personality!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ]),

                      // 메모
                      if (person.note != null)
                        _buildSection(context, '메모', [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Text(
                              person.note!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ]),

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
                                  ? const Icon(
                                      Iconsax.repeat,
                                      size: 16,
                                      color: Colors.grey,
                                    )
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull,
                                ),
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

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // 아바타
        CircleAvatar(
          radius: 40,
          backgroundColor: _getRelationshipColor(
            person.relationship,
          ).withValues(alpha: 0.2),
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
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
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditSheet(context);
                break;
              case 'delete':
                _confirmDeletePerson(context, ref);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(value: 'edit', child: Text('정보 수정')),
            PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
          ],
          icon: const Icon(Iconsax.more),
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
              _makePhoneCall(context);
            },
          ),
        if (person.phone != null)
          _QuickActionButton(
            icon: Iconsax.message,
            label: '문자',
            color: const Color(0xFF7C4DFF),
            onTap: () {
              _sendSms(context);
            },
          ),
        if (person.email != null)
          _QuickActionButton(
            icon: Iconsax.sms,
            label: '이메일',
            color: const Color(0xFFFFA726),
            onTap: () {
              _sendEmail(context);
            },
          ),
        _QuickActionButton(
          icon: Iconsax.calendar_add,
          label: '일정추가',
          color: peopleColor,
          onTap: () {
            _addCalendarEvent(context);
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
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.spacingS),
        ...children,
      ],
    );
  }

  Widget _buildAssistantSection(
    BuildContext context,
    PeopleCareTarget careTarget,
  ) {
    final scoreColor = _careScoreColor(careTarget.score);

    return _buildSection(context, 'AI 챙김 요약', [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.star_1, size: 16, color: Color(0xFFFFA726)),
                const SizedBox(width: 6),
                Text(
                  '챙김 우선순위 ${careTarget.score}점',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (careTarget.score / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: scoreColor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '챙김 포인트',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...careTarget.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '추천 선물/행동',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: careTarget.giftSuggestions.map((suggestion) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    suggestion,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ]);
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

  Future<void> _showEditSheet(BuildContext context) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddPersonSheet(initialPerson: person),
    );
    if (edited == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDeletePerson(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('사람 삭제'),
        content: Text('${person.name}님의 정보를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('삭제', style: TextStyle(color: AppColors.errorLight)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(peopleServiceProvider).deletePerson(person.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${person.name}님이 삭제되었습니다'),
          backgroundColor: AppColors.errorLight,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final phone = _normalizedPhone(person.phone);
    if (phone == null) {
      _showActionError(context, '전화번호가 없습니다.');
      return;
    }
    await _openUri(
      context,
      Uri(scheme: 'tel', path: phone),
      failureMessage: '전화 앱을 열 수 없습니다.',
    );
  }

  Future<void> _sendSms(BuildContext context) async {
    final phone = _normalizedPhone(person.phone);
    if (phone == null) {
      _showActionError(context, '문자를 보낼 전화번호가 없습니다.');
      return;
    }
    await _openUri(
      context,
      Uri(scheme: 'sms', path: phone),
      failureMessage: '문자 앱을 열 수 없습니다.',
    );
  }

  Future<void> _sendEmail(BuildContext context) async {
    final email = _normalizedEmail(person.email);
    if (email == null) {
      _showActionError(context, '이메일 주소가 없습니다.');
      return;
    }
    await _openUri(
      context,
      Uri(scheme: 'mailto', path: email),
      failureMessage: '이메일 앱을 열 수 없습니다.',
    );
  }

  Future<void> _addCalendarEvent(BuildContext context) async {
    final now = DateTime.now();
    final startUtc = now.add(const Duration(hours: 1)).toUtc();
    final endUtc = startUtc.add(const Duration(hours: 1));

    final start = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(startUtc);
    final end = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(endUtc);

    final details = <String>[
      '${person.name} 관련 일정',
      if (_normalizedPhone(person.phone) != null) '전화: ${person.phone}',
      if (_normalizedEmail(person.email) != null) '이메일: ${person.email}',
      if ((person.note ?? '').trim().isNotEmpty) '메모: ${person.note}',
    ].join('\n');

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': '${person.name} 일정',
      'dates': '$start/$end',
      'details': details,
    });

    await _openUri(context, uri, failureMessage: '캘린더를 열 수 없습니다.');
  }

  String? _normalizedPhone(String? rawPhone) {
    if (rawPhone == null) return null;
    final normalized = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizedEmail(String? rawEmail) {
    if (rawEmail == null) return null;
    final normalized = rawEmail.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _openUri(
    BuildContext context,
    Uri uri, {
    required String failureMessage,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (!context.mounted) return;
      _showActionError(context, failureMessage);
    } catch (_) {
      if (!context.mounted) return;
      _showActionError(context, failureMessage);
    }
  }

  void _showActionError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Color _careScoreColor(int score) {
    if (score >= 80) return const Color(0xFFE53935);
    if (score >= 60) return const Color(0xFFFFA726);
    if (score >= 40) return const Color(0xFF1E88E5);
    return const Color(0xFF43A047);
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
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
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
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
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
