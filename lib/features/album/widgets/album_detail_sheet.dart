import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/album.dart';
import '../../../shared/providers/album_provider.dart';
import '../../../shared/providers/smart_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 앨범 상세 바텀 시트
class AlbumDetailSheet extends ConsumerStatefulWidget {
  final Album album;

  const AlbumDetailSheet({super.key, required this.album});

  @override
  ConsumerState<AlbumDetailSheet> createState() => _AlbumDetailSheetState();
}

class _AlbumDetailSheetState extends ConsumerState<AlbumDetailSheet> {
  final _commentController = TextEditingController();
  bool _isAddingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isAddingComment = true);

    try {
      final albumService = ref.read(albumServiceProvider);
      await albumService.addComment(
        widget.album.id,
        _commentController.text.trim(),
      );
      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() => _isAddingComment = false);
      }
    }
  }

  Future<void> _deleteAlbum() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앨범 삭제'),
        content: const Text('이 앨범을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(albumServiceProvider).deleteAlbum(widget.album.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserProvider)?.uid;
    final members = ref.watch(smartMembersProvider);
    final comments =
        ref.watch(albumCommentsProvider(widget.album.id)).value ?? [];
    final isOwner = widget.album.createdBy == currentUserId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사진 갤러리
                  if (widget.album.photoUrls.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: widget.album.photoUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: widget.album.photoUrls[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.memoryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.memoryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  child: const Icon(
                                    Iconsax.gallery,
                                    color: AppColors.memoryColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.memoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Iconsax.gallery,
                          size: 48,
                          color: AppColors.memoryColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppTheme.spacingL),

                  // 제목 + 삭제 버튼
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.album.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          onPressed: _deleteAlbum,
                          icon: const Icon(Iconsax.trash),
                          color: AppColors.errorLight,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // 장소 및 날짜
                  Row(
                    children: [
                      if (widget.album.hasLocation &&
                          widget.album.placeName != null) ...[
                        Icon(
                          Iconsax.location,
                          size: 16,
                          color: AppColors.memoryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.album.placeName!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.memoryColor),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Icon(
                        Iconsax.calendar_1,
                        size: 16,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy년 M월 d일').format(widget.album.date),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // 타입 + 공유 뱃지
                  Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.memoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                        child: Text(
                          widget.album.albumType.label,
                          style: TextStyle(
                            color: AppColors.memoryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.album.sharedGroups.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.share,
                                size: 12,
                                color: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.album.sharedGroups.length}개 그룹 공유',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // 태그
                  if (widget.album.tags.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.album.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // 참여자
                  if (widget.album.participants.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Text('참여자', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppTheme.spacingS),
                    Wrap(
                      spacing: 8,
                      children: widget.album.participants.map((participantId) {
                        final matchedMembers = members.where(
                          (m) => m.id == participantId,
                        );
                        final member = matchedMembers.isNotEmpty
                            ? matchedMembers.first
                            : null;
                        final participantName = member?.name ?? '알 수 없음';

                        return Chip(
                          avatar: MemberAvatar(
                            member: member,
                            name: participantName,
                            size: 24,
                          ),
                          label: Text(participantName),
                        );
                      }).toList(),
                    ),
                  ],

                  // 설명
                  if (widget.album.description != null &&
                      widget.album.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      widget.album.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingM),

                  // 댓글 섹션
                  Text(
                    '댓글 ${comments.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 댓글 목록
                  ...comments.map((comment) {
                    final matchedAuthors = members.where(
                      (m) => m.id == comment.userId,
                    );
                    final author = matchedAuthors.isNotEmpty
                        ? matchedAuthors.first
                        : null;
                    final authorName = author?.name ?? '알 수 없음';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemberAvatar(
                            member: author,
                            name: authorName,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      authorName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat(
                                        'M/d HH:mm',
                                      ).format(comment.createdAt),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comment.text,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: AppTheme.spacingXL),
                ],
              ),
            ),
          ),

          // 댓글 입력
          Container(
            padding: EdgeInsets.only(
              left: AppTheme.spacingL,
              right: AppTheme.spacingL,
              top: AppTheme.spacingS,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingM,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: '댓글 작성...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isAddingComment ? null : _addComment,
                  icon: _isAddingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Iconsax.send_15),
                  color: AppColors.memoryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
