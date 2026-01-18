import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/providers/memory_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/member_avatar.dart';

/// 추억 상세 바텀 시트
class MemoryDetailSheet extends ConsumerStatefulWidget {
  final Memory memory;

  const MemoryDetailSheet({super.key, required this.memory});

  @override
  ConsumerState<MemoryDetailSheet> createState() => _MemoryDetailSheetState();
}

class _MemoryDetailSheetState extends ConsumerState<MemoryDetailSheet> {
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
      final memoryService = ref.read(memoryServiceProvider);
      await memoryService.addComment(
        widget.memory.id,
        _commentController.text.trim(),
      );
      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() => _isAddingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comments = ref.watch(memoryCommentsProvider(widget.memory.id)).value ?? [];
    final members = ref.watch(familyMembersProvider).value ?? [];

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
                  color: (isDark
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
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사진 갤러리
                  if (widget.memory.photoUrls.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        itemCount: widget.memory.photoUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              child: CachedNetworkImage(
                                imageUrl: widget.memory.photoUrls[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.memoryColor.withValues(alpha: 0.2),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.memoryColor.withValues(alpha: 0.2),
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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

                  // 제목
                  Text(
                    widget.memory.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // 장소 및 날짜
                  Row(
                    children: [
                      Icon(
                        Iconsax.location,
                        size: 16,
                        color: AppColors.memoryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.memory.placeName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.memoryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Iconsax.calendar_1,
                        size: 16,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy년 M월 d일').format(widget.memory.date),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),

                  // 카테고리 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.memoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      MemoryCategory.getLabel(widget.memory.category),
                      style: TextStyle(
                        color: AppColors.memoryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // 설명
                  if (widget.memory.description != null &&
                      widget.memory.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      widget.memory.description!,
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
                    final author = members.firstWhere(
                      (m) => m.id == comment.userId,
                      orElse: () => members.isNotEmpty ? members.first : throw Exception('No members'),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MemberAvatar(member: author, size: 32),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      author.name,
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('M/d HH:mm').format(comment.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall,
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
              bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingM,
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
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
