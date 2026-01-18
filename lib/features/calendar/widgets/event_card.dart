import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/family_member.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 이벤트 카드
class EventCard extends StatelessWidget {
  final Event event;
  final List<dynamic> members;

  const EventCard({
    super.key,
    required this.event,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final participants = members
        .where((m) => event.participants.contains(m.id))
        .cast<FamilyMember>()
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 색상 바
              Container(
                width: 4,
                color: AppColors.calendarColor,
              ),
              // 내용
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 시간
                      Row(
                        children: [
                          Icon(
                            Iconsax.clock,
                            size: 14,
                            color: AppColors.calendarColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.isAllDay
                                ? '종일'
                                : '${DateFormat('HH:mm').format(event.startAt)} - ${DateFormat('HH:mm').format(event.endAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.calendarColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 제목
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 설명
                      if (event.description != null && event.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 장소
                      if (event.location != null && event.location!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Iconsax.location,
                              size: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // 참여자
                      if (participants.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              ...participants.take(4).map((member) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: MemberAvatar(
                                      member: member,
                                      size: 24,
                                    ),
                                  )),
                              if (participants.length > 4)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.backgroundDark
                                        : AppColors.backgroundLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${participants.length - 4}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
