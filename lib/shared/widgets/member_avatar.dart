import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/family_member.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/color_utils.dart';

/// 가족 구성원 아바타 위젯
class MemberAvatar extends StatelessWidget {
  final FamilyMember? member;
  final String? name;
  final String? color;
  final String? avatarUrl;
  final double size;
  final bool showName;
  final bool isSelected;
  final VoidCallback? onTap;

  const MemberAvatar({
    super.key,
    this.member,
    this.name,
    this.color,
    this.avatarUrl,
    this.size = 40,
    this.showName = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final memberName = member?.name ?? name ?? '?';
    final memberColor = parseHexColor(member?.color ?? color, fallback: AppColors.memberColors[0]);
    final memberAvatar = member?.avatarUrl ?? avatarUrl;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: memberColor,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: memberColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: memberAvatar != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: memberAvatar,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildInitials(memberName),
                      errorWidget: (context, url, error) =>
                          _buildInitials(memberName),
                    ),
                  )
                : _buildInitials(memberName),
          ),
          if (showName) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: size + 16,
              child: Text(
                memberName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

}

/// 가족 구성원 아바타 리스트
class MemberAvatarList extends StatelessWidget {
  final List<FamilyMember> members;
  final String? selectedMemberId;
  final Function(String?)? onMemberSelected;
  final bool showAll;
  final double size;

  const MemberAvatarList({
    super.key,
    required this.members,
    this.selectedMemberId,
    this.onMemberSelected,
    this.showAll = true,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showAll)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _AllMembersButton(
                size: size,
                isSelected: selectedMemberId == null,
                onTap: () => onMemberSelected?.call(null),
              ),
            ),
          ...members.map((member) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: MemberAvatar(
                  member: member,
                  size: size,
                  showName: true,
                  isSelected: selectedMemberId == member.id,
                  onTap: () => onMemberSelected?.call(member.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _AllMembersButton extends StatelessWidget {
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  const _AllMembersButton({
    required this.size,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight)
                            .withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Icon(
              Icons.groups_outlined,
              size: size * 0.5,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: size + 16,
            child: Text(
              '전체',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
