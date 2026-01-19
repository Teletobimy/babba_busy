import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/people_provider.dart';
import '../../shared/models/person.dart';
import 'widgets/add_person_sheet.dart';
import 'widgets/person_card.dart';
import 'widgets/person_detail_sheet.dart';

/// 사람들 탭 컬러
const Color peopleColor = Color(0xFF5B8DEF);

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(displayPeopleProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedRelationship = ref.watch(selectedRelationshipFilterProvider);
    final upcomingBirthdays = ref.watch(upcomingBirthdaysProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Column(
          children: [
            // 검색 바
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: TextField(
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
                decoration: InputDecoration(
                  hintText: '이름, 전화번호, 회사, 태그로 검색',
                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle, size: 20),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // 관계 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  _RelationshipChip(
                    label: '전체',
                    isSelected: selectedRelationship == null,
                    onTap: () {
                      ref.read(selectedRelationshipFilterProvider.notifier).state =
                          null;
                    },
                  ),
                  const SizedBox(width: 8),
                  ...PersonRelationship.all.map((rel) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RelationshipChip(
                        label: PersonRelationship.getLabel(rel),
                        isSelected: selectedRelationship == rel,
                        onTap: () {
                          ref
                              .read(selectedRelationshipFilterProvider.notifier)
                              .state = rel;
                        },
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: AppTheme.spacingM),

            // 다가오는 생일 (있을 경우)
            if (upcomingBirthdays.isNotEmpty && selectedRelationship == null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      peopleColor.withValues(alpha: 0.15),
                      const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.cake, size: 18, color: Color(0xFFFF6B6B)),
                        const SizedBox(width: 8),
                        Text(
                          '다가오는 생일',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: const Color(0xFFFF6B6B),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: upcomingBirthdays.length.clamp(0, 5),
                        itemBuilder: (context, index) {
                          final person = upcomingBirthdays[index];
                          final daysLeft = person.daysUntilBirthday ?? 0;
                          return GestureDetector(
                            onTap: () => _showPersonDetail(context, person),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        peopleColor.withValues(alpha: 0.2),
                                    child: Text(
                                      person.name[0],
                                      style: TextStyle(
                                        color: peopleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        daysLeft == 0
                                            ? '오늘!'
                                            : 'D-$daysLeft',
                                        style: TextStyle(
                                          color: daysLeft <= 7
                                              ? const Color(0xFFFF6B6B)
                                              : peopleColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            if (upcomingBirthdays.isNotEmpty && selectedRelationship == null)
              const SizedBox(height: AppTheme.spacingM),

            // 사람 목록
            Expanded(
              child: people.isEmpty
                  ? _EmptyState(
                      searchQuery: searchQuery,
                      onAdd: () => _showAddPersonSheet(context),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                      ),
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final person = people[index];
                        return PersonCard(
                          person: person,
                          onTap: () => _showPersonDetail(context, person),
                        ).animate().fadeIn(
                              duration: 200.ms,
                              delay: Duration(milliseconds: 50 * (index % 10)),
                            );
                      },
                    ),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'people_fab',
            onPressed: () => _showAddPersonSheet(context),
            backgroundColor: peopleColor,
            child: const Icon(Iconsax.user_add),
          ).animate().scale(delay: 400.ms, duration: 300.ms),
        ),
      ],
    );
  }

  void _showAddPersonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddPersonSheet(),
    );
  }

  void _showPersonDetail(BuildContext context, Person person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonDetailSheet(person: person),
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RelationshipChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? peopleColor : peopleColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : peopleColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.searchQuery,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchQuery.isNotEmpty ? Iconsax.search_status : Iconsax.people,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '등록된 사람이 없습니다',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              searchQuery.isNotEmpty
                  ? '다른 검색어로 시도해보세요'
                  : '주변 사람들의 정보를 기록해보세요',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Iconsax.user_add),
                label: const Text('사람 추가하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: peopleColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
