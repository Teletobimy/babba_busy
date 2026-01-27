import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/album_provider.dart';
import '../../shared/providers/smart_provider.dart';
import '../../shared/models/album.dart';
import 'widgets/add_album_sheet.dart';
import 'widgets/album_detail_sheet.dart';

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(albumViewModeProvider);
    final selectedType = ref.watch(selectedAlbumTypeProvider);
    final albums = ref.watch(filteredAlbumsProvider);
    final allAlbums = ref.watch(combinedAlbumsProvider);

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
                        '앨범',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${albums.length}개의 앨범',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.memoryColor,
                            ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  // 뷰 모드 전환 버튼
                  PopupMenuButton<AlbumViewMode>(
                    icon: Icon(_getViewModeIcon(viewMode)),
                    onSelected: (mode) {
                      ref.read(albumViewModeProvider.notifier).state = mode;
                    },
                    itemBuilder: (context) => AlbumViewMode.values
                        .map((mode) => PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  Icon(
                                    _getViewModeIcon(mode),
                                    size: 20,
                                    color: viewMode == mode
                                        ? AppColors.memoryColor
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      color: viewMode == mode
                                          ? AppColors.memoryColor
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

            // 타입 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Row(
                children: [
                  _AlbumTypeChip(
                    label: '전체',
                    count: allAlbums.length,
                    isSelected: selectedType == null,
                    onTap: () =>
                        ref.read(selectedAlbumTypeProvider.notifier).state =
                            null,
                  ),
                  const SizedBox(width: 8),
                  ...AlbumType.values.map((type) {
                    final count =
                        allAlbums.where((a) => a.albumType == type).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AlbumTypeChip(
                        label: type.label,
                        count: count,
                        isSelected: selectedType == type,
                        onTap: () => ref
                            .read(selectedAlbumTypeProvider.notifier)
                            .state = type,
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: AppTheme.spacingM),

            // 콘텐츠
            Expanded(
              child: _buildContent(context, ref, viewMode, albums),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlbumSheet(context),
        backgroundColor: AppColors.memoryColor,
        child: const Icon(Iconsax.add),
      ).animate().scale(delay: 500.ms, duration: 300.ms),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, AlbumViewMode viewMode, List<Album> albums) {
    switch (viewMode) {
      case AlbumViewMode.timeline:
        return _TimelineView(albums: albums);
      case AlbumViewMode.person:
        return _PersonView(albums: albums);
      case AlbumViewMode.location:
        return _LocationView(albums: albums);
    }
  }

  IconData _getViewModeIcon(AlbumViewMode mode) {
    switch (mode) {
      case AlbumViewMode.timeline:
        return Iconsax.calendar_1;
      case AlbumViewMode.person:
        return Iconsax.people;
      case AlbumViewMode.location:
        return Iconsax.location;
    }
  }

  void _showAddAlbumSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAlbumSheet(),
    );
  }
}

/// 타입 필터 칩
class _AlbumTypeChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlbumTypeChip({
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

/// 시간순 뷰
class _TimelineView extends ConsumerWidget {
  final List<Album> albums;

  const _TimelineView({required this.albums});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) {
      return AlbumEmptyState(
        onAdd: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddAlbumSheet(),
        ),
      ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
    }

    // 월별로 그룹화
    final groupedAlbums = <String, List<Album>>{};
    for (final album in albums) {
      final key = DateFormat('yyyy년 M월').format(album.date);
      groupedAlbums.putIfAbsent(key, () => []).add(album);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      itemCount: groupedAlbums.length,
      itemBuilder: (context, index) {
        final entry = groupedAlbums.entries.elementAt(index);
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
                return AlbumCard(album: entry.value[gridIndex])
                    .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: Duration(milliseconds: 50 * gridIndex),
                    )
                    .scale(begin: const Offset(0.95, 0.95));
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
        );
      },
    );
  }
}

/// 사람별 뷰
class _PersonView extends ConsumerWidget {
  final List<Album> albums;

  const _PersonView({required this.albums});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsByPerson = ref.watch(albumsByPersonProvider);
    final members = ref.watch(smartMembersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (albumsByPerson.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.people,
              size: 64,
              color: AppColors.memoryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              '참여자 정보가 있는 앨범이 없습니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      itemCount: albumsByPerson.length,
      itemBuilder: (context, index) {
        final entry = albumsByPerson.entries.elementAt(index);
        final personId = entry.key;
        final personAlbums = entry.value;

        // 멤버 이름 찾기
        String personName;
        if (personId == '_other') {
          personName = '기타';
        } else {
          final member = members.firstWhere(
            (m) => m.id == personId,
            orElse: () => members.isNotEmpty ? members.first : throw Exception('No members'),
          );
          personName = member.name;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.user, size: 20, color: AppColors.memoryColor),
                const SizedBox(width: 8),
                Text(
                  personName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '${personAlbums.length}개',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: personAlbums.length,
                itemBuilder: (context, albumIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 150,
                      child: AlbumCard(album: personAlbums[albumIndex]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        );
      },
    );
  }
}

/// 장소별 뷰
class _LocationView extends ConsumerWidget {
  final List<Album> albums;

  const _LocationView({required this.albums});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsByLocation = ref.watch(albumsByLocationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (albumsByLocation.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.location,
              size: 64,
              color: AppColors.memoryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              '위치 정보가 있는 앨범이 없습니다',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '앨범 추가 시 위치 정보를 입력해보세요',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      itemCount: albumsByLocation.length,
      itemBuilder: (context, index) {
        final entry = albumsByLocation.entries.elementAt(index);
        final placeName = entry.key;
        final locationAlbums = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.location, size: 20, color: AppColors.memoryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    placeName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${locationAlbums.length}개',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: locationAlbums.length,
                itemBuilder: (context, albumIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 150,
                      child: AlbumCard(album: locationAlbums[albumIndex]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        );
      },
    );
  }
}

/// 앨범 카드
class AlbumCard extends ConsumerWidget {
  final Album album;

  const AlbumCard({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showAlbumDetail(context, album),
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
              if (album.photoUrls.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: album.photoUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.memoryColor.withValues(alpha: 0.2),
                  ),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(album.albumType),
                )
              else
                _buildPlaceholder(album.albumType),
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
              // 타입 뱃지
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(album.albumType).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    album.albumType.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // 공유 뱃지
              if (album.sharedGroups.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.share,
                      size: 12,
                      color: Colors.white,
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
                      album.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (album.hasLocation && album.placeName != null) ...[
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
                              album.placeName!,
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
                    ],
                    Text(
                      DateFormat('yyyy.MM.dd').format(album.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // 사진 개수 뱃지
              if (album.photoUrls.length > 1)
                Positioned(
                  bottom: 8,
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
                          '${album.photoUrls.length}',
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

  Widget _buildPlaceholder(AlbumType type) {
    return Container(
      color: _getTypeColor(type).withValues(alpha: 0.3),
      child: Icon(
        _getTypeIcon(type),
        size: 32,
        color: Colors.white54,
      ),
    );
  }

  Color _getTypeColor(AlbumType type) {
    switch (type) {
      case AlbumType.kids:
        return const Color(0xFFE91E63);
      case AlbumType.family:
        return const Color(0xFF3498DB);
      case AlbumType.event:
        return const Color(0xFFF39C12);
      case AlbumType.moment:
        return const Color(0xFF2ECC71);
    }
  }

  IconData _getTypeIcon(AlbumType type) {
    switch (type) {
      case AlbumType.kids:
        return Iconsax.emoji_happy;
      case AlbumType.family:
        return Iconsax.people;
      case AlbumType.event:
        return Iconsax.star;
      case AlbumType.moment:
        return Iconsax.sun_1;
    }
  }

  void _showAlbumDetail(BuildContext context, Album album) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlbumDetailSheet(album: album),
    );
  }
}

/// 앨범 빈 상태 위젯
class AlbumEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const AlbumEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.gallery,
            size: 64,
            color: AppColors.memoryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            '아직 앨범이 없어요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '소중한 순간을 앨범에 담아보세요',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Iconsax.add),
            label: const Text('첫 앨범 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.memoryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
