import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/person.dart';

// peopleColor는 AppColors.peopleColor를 사용합니다.

class PersonCard extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const PersonCard({
    super.key,
    required this.person,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysUntilBirthday = person.daysUntilBirthday;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        ),
        child: Row(
          children: [
            // 프로필 아바타
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _getRelationshipColor(person.relationship)
                      .withValues(alpha: 0.2),
                  backgroundImage: person.profilePhotoUrl != null
                      ? NetworkImage(person.profilePhotoUrl!)
                      : null,
                  child: person.profilePhotoUrl == null
                      ? Text(
                          person.name.isNotEmpty ? person.name[0] : '?',
                          style: TextStyle(
                            color: _getRelationshipColor(person.relationship),
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                // 생일 임박 표시
                if (daysUntilBirthday != null && daysUntilBirthday <= 7)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.birthdayCountdown,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark ? AppColors.surfaceDark : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Iconsax.cake,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingM),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (person.mbti != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.peopleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            person.mbti!,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.peopleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 관계 + 회사
                  Row(
                    children: [
                      if (person.relationship != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRelationshipColor(person.relationship)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            PersonRelationship.getLabel(person.relationship!),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getRelationshipColor(person.relationship),
                            ),
                          ),
                        ),
                      if (person.relationship != null && person.company != null)
                        const SizedBox(width: 6),
                      if (person.company != null)
                        Expanded(
                          child: Text(
                            person.company!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  // 생일 정보
                  if (person.birthday != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.cake,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('M월 d일').format(person.birthday!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (daysUntilBirthday != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            daysUntilBirthday == 0
                                ? '오늘!'
                                : 'D-$daysUntilBirthday',
                            style: TextStyle(
                              fontSize: 11,
                              color: daysUntilBirthday <= 7
                                  ? AppColors.birthdayCountdown
                                  : AppColors.peopleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  // 태그
                  if (person.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: person.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            // 화살표
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

  Color _getRelationshipColor(String? relationship) {
    switch (relationship) {
      case PersonRelationship.family:
        return AppColors.relationFamily;
      case PersonRelationship.friend:
        return AppColors.relationFriend;
      case PersonRelationship.colleague:
        return AppColors.relationColleague;
      case PersonRelationship.school:
        return AppColors.relationSchool;
      case PersonRelationship.neighbor:
        return AppColors.relationNeighbor;
      default:
        return AppColors.relationOther;
    }
  }
}
