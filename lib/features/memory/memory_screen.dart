import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/providers/memory_provider.dart';
import '../../shared/models/memory.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/app_card.dart';
import 'widgets/add_memory_sheet.dart';
import 'widgets/memory_detail_sheet.dart';

/// 뷰 모드 Provider (지도/타임라인)
final memoryViewModeProvider = StateProvider<bool>((ref) => false); // false = 타임라인, true = 지도
/// 선택된 카테고리 Provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMapView = ref.watch(memoryViewModeProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    
    // Smart Provider 사용
    final allMemories = ref.watch(smartMemoriesProvider);
    final memories = selectedCategory == null
        ? allMemories
        : allMemories.where((m) => m.category == selectedCategory).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '추억',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${memories.length}개의 추억',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.memoryColor,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  Row(
                    children: [
                      // 뷰 모드 전환
                      IconButton(
                        onPressed: () {
                          ref.read(memoryViewModeProvider.notifier).state = !isMapView;
                        },
                        icon: Icon(
                          isMapView ? Iconsax.grid_1 : Iconsax.map_1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 카테고리 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  _CategoryChip(
                    label: '전체',
                    count: allMemories.length,
                    isSelected: selectedCategory == null,
                    onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  ...MemoryCategory.all.map((category) {
                    final count = allMemories.where((m) => m.category == category).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: MemoryCategory.getLabel(category),
                        count: count,
                        isSelected: selectedCategory == category,
                        onTap: () =>
                            ref.read(selectedCategoryProvider.notifier).state = category,
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: AppTheme.spacingM),

            // 콘텐츠
            Expanded(
              child: isMapView
                  ? _MapView(memories: memories)
                  : _TimelineView(memories: memories),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemorySheet(context),
        backgroundColor: AppColors.memoryColor,
        child: const Icon(Iconsax.add),
      ).animate().scale(delay: 500.ms, duration: 300.ms),
    );
  }

  void _showAddMemorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMemorySheet(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.memoryColor
              : AppColors.memoryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.memoryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.memoryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.memoryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 타임라인 뷰
class _TimelineView extends ConsumerWidget {
  final List<Memory> memories;

  const _TimelineView({required this.memories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (memories.isEmpty) {
      return MemoryEmptyState(
        onAdd: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddMemorySheet(),
        ),
      ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
    }

    // 월별로 그룹화
    final groupedMemories = <String, List<Memory>>{};
    for (final memory in memories) {
      final key = DateFormat('yyyy년 M월').format(memory.date);
      groupedMemories.putIfAbsent(key, () => []).add(memory);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      itemCount: groupedMemories.length,
      itemBuilder: (context, index) {
        final entry = groupedMemories.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.memoryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value.length}개',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ).animate().fadeIn(
                  duration: 300.ms,
                  delay: Duration(milliseconds: 100 * index),
                ),
            // 그리드 형태로 표시
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, gridIndex) {
                return _MemoryCard(
                  memory: entry.value[gridIndex],
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: 50 * gridIndex),
                    ).scale(begin: const Offset(0.95, 0.95));
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
        );
      },
    );
  }
}

/// 지도 뷰 (플레이스홀더 - 네이버 지도 SDK 연동 필요)
class _MapView extends StatelessWidget {
  final List<Memory> memories;

  const _MapView({required this.memories});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // 지도 플레이스홀더
        Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.map_1,
                  size: 64,
                  color: AppColors.memoryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  '지도 뷰',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '네이버 지도 SDK 연동 필요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  '총 ${memories.length}개의 추억이 있습니다',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.memoryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 하단 추억 미리보기 리스트
        if (memories.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                        .withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: memories.length,
                itemBuilder: (context, index) {
                  return _MemoryPreviewCard(memory: memories[index])
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 50 * index))
                      .slideX(begin: 0.1);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// 추억 카드
class _MemoryCard extends ConsumerWidget {
  final Memory memory;

  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showMemoryDetail(context, memory),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          boxShadow: isDark ? AppTheme.softShadowDark : AppTheme.softShadowLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 배경 이미지 또는 플레이스홀더
              if (memory.photoUrls.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: memory.photoUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.memoryColor.withValues(alpha: 0.2),
                  ),
                  errorWidget: (context, url, error) => _buildPlaceholder(memory.category),
                )
              else
                _buildPlaceholder(memory.category),
              // 그라데이션 오버레이
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // 카테고리 뱃지
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(memory.category).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    MemoryCategory.getLabel(memory.category),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // 정보
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      memory.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Iconsax.location,
                          size: 10,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            memory.placeName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy.MM.dd').format(memory.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // 사진 개수 뱃지
              if (memory.photoUrls.length > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.gallery,
                          size: 10,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${memory.photoUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
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

  Widget _buildPlaceholder(String category) {
    return Container(
      color: _getCategoryColor(category).withValues(alpha: 0.3),
      child: Icon(
        _getCategoryIcon(category),
        size: 32,
        color: Colors.white54,
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'travel':
        return const Color(0xFF3498DB);
      case 'food':
        return const Color(0xFFE74C3C);
      case 'daily':
        return const Color(0xFF2ECC71);
      case 'special':
        return const Color(0xFFF39C12);
      default:
        return AppColors.memoryColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'travel':
        return Iconsax.airplane;
      case 'food':
        return Iconsax.coffee;
      case 'daily':
        return Iconsax.sun_1;
      case 'special':
        return Iconsax.star;
      default:
        return Iconsax.gallery;
    }
  }

  void _showMemoryDetail(BuildContext context, Memory memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoryDetailSheet(memory: memory),
    );
  }
}

/// 지도 뷰용 미리보기 카드
class _MemoryPreviewCard extends StatelessWidget {
  final Memory memory;

  const _MemoryPreviewCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // 썸네일
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.memoryColor.withValues(alpha: 0.2),
              ),
              child: memory.photoUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: memory.photoUrls.first,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Iconsax.gallery,
                      color: AppColors.memoryColor,
                    ),
            ),
            const SizedBox(width: 8),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    memory.title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    memory.placeName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('M/d').format(memory.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.memoryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
