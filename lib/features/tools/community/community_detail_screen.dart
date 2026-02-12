import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/community.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/community_provider.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  Future<void> _showCreatePostSheet() async {
    if (ref.read(currentUserProvider) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 글을 작성할 수 있습니다.')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(communityId: widget.communityId),
    );
  }

  Future<void> _confirmDeletePost(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글과 댓글이 모두 삭제됩니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(communityServiceProvider)
          .deletePost(communityId: widget.communityId, postId: post.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('게시글 삭제 실패: $e')));
    }
  }

  void _openPostDetail(CommunityPost post) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PostDetailSheet(communityId: widget.communityId, post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final communityAsync = ref.watch(communityProvider(widget.communityId));
    final postsAsync = ref.watch(communityPostsProvider(widget.communityId));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.uid;
    final isLoggedIn = currentUser != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noticeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Scaffold(
      appBar: AppBar(
        title: communityAsync.when(
          data: (community) => Text(community?.name ?? '커뮤니티'),
          loading: () => const Text('커뮤니티'),
          error: (_, __) => const Text('커뮤니티'),
        ),
        actions: [
          IconButton(
            onPressed: isLoggedIn
                ? _showCreatePostSheet
                : () => context.push('/auth/login'),
            icon: Icon(isLoggedIn ? Iconsax.edit_2 : Iconsax.login_1),
            tooltip: isLoggedIn ? '글쓰기' : '로그인',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoggedIn ? _showCreatePostSheet : null,
        backgroundColor: AppColors.communityColor,
        foregroundColor: Colors.white,
        icon: Icon(isLoggedIn ? Iconsax.edit_2 : Iconsax.lock_1),
        label: Text(isLoggedIn ? '글쓰기' : '로그인 후 작성'),
      ),
      body: Column(
        children: [
          communityAsync.when(
            data: (community) {
              if (community == null) {
                return const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Text('존재하지 않는 커뮤니티입니다.'),
                );
              }
              return _CommunityHeaderCard(community: community);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Text('커뮤니티 정보를 불러오지 못했습니다.\n$error'),
            ),
          ),
          if (!isLoggedIn)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppTheme.spacingL,
                0,
                AppTheme.spacingL,
                AppTheme.spacingS,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? noticeColor.withValues(alpha: 0.15)
                    : noticeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: noticeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '읽기 전용 모드입니다. 글/댓글 작성은 로그인 후 가능합니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/auth/login'),
                    child: const Text('로그인'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingL),
                      child: Text('첫 게시글을 작성해보세요.'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingL,
                    AppTheme.spacingS,
                    AppTheme.spacingL,
                    100,
                  ),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isOwner = post.authorId == currentUserId;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        onTap: () => _openPostDetail(post),
                        child: Ink(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      post.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _confirmDeletePost(post);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('삭제'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: post.tags
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.communityColor
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.communityColor,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Iconsax.user,
                                    size: 13,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    post.authorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Iconsax.clock,
                                    size: 13,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat(
                                      'yy.MM.dd HH:mm',
                                    ).format(post.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  const Icon(Iconsax.message, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    '댓글',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.spacingS),
                  itemCount: posts.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Text('게시글을 불러오지 못했습니다.\n$error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityHeaderCard extends StatelessWidget {
  final CommunitySpace community;

  const _CommunityHeaderCard({required this.community});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingL,
        AppTheme.spacingM,
        AppTheme.spacingL,
        AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppColors.communityColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.communityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Iconsax.message_question,
                  size: 18,
                  color: AppColors.communityColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  community.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            community.description.isEmpty ? '설명이 없습니다.' : community.description,
          ),
          const SizedBox(height: 8),
          Text(
            '개설자: ${community.createdByName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: community.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.communityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.communityColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends ConsumerStatefulWidget {
  final String communityId;

  const _CreatePostSheet({required this.communityId});

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('본문을 입력해주세요.')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final postId = await ref
          .read(communityServiceProvider)
          .createPost(
            communityId: widget.communityId,
            title: title,
            content: content,
            tags: _parseTags(_tagsController.text),
          );
      if (postId == null) {
        throw Exception('로그인 후 이용해주세요.');
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacingL,
            AppTheme.spacingL,
            AppTheme.spacingL,
            AppTheme.spacingL + insets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('새 글 작성', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '제목 *',
                    hintText: '글 제목을 입력하세요',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                TextField(
                  controller: _contentController,
                  maxLength: 5000,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '본문 *',
                    hintText: '내용을 입력하세요',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '태그 (쉼표 구분)',
                    hintText: '예: 질문, 정보',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Iconsax.edit_2),
                    label: Text(_submitting ? '등록 중...' : '등록하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.communityColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostDetailSheet extends ConsumerStatefulWidget {
  final String communityId;
  final CommunityPost post;

  const _PostDetailSheet({required this.communityId, required this.post});

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _sendingComment = false;
  bool get _canSubmitComment =>
      !_sendingComment && _commentController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_sendingComment) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 내용을 입력해주세요.')));
      return;
    }

    if (ref.read(currentUserProvider) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 댓글을 작성할 수 있습니다.')));
      return;
    }

    setState(() => _sendingComment = true);
    try {
      await ref
          .read(communityServiceProvider)
          .addComment(
            communityId: widget.communityId,
            postId: widget.post.id,
            content: content,
          );
      _commentController.clear();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref
          .read(communityServiceProvider)
          .deleteComment(
            communityId: widget.communityId,
            postId: widget.post.id,
            commentId: comment.id,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('댓글 삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final commentsAsync = ref.watch(
      communityCommentsProvider((
        communityId: widget.communityId,
        postId: widget.post.id,
      )),
    );
    final currentUserId = ref.watch(currentUserProvider)?.uid;
    final isLoggedIn = currentUserId != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingL,
                    AppTheme.spacingM,
                    AppTheme.spacingS,
                    AppTheme.spacingS,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '게시글 상세',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingL,
                    ),
                    children: [
                      Text(
                        widget.post.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            widget.post.authorName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'yy.MM.dd HH:mm',
                            ).format(widget.post.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.post.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.post.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.communityColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.communityColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        '댓글',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      commentsAsync.when(
                        data: (comments) {
                          if (comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('아직 댓글이 없습니다.'),
                            );
                          }

                          return Column(
                            children: comments.map((comment) {
                              final isOwner = comment.authorId == currentUserId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment.authorName,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat(
                                                  'MM.dd HH:mm',
                                                ).format(comment.createdAt),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(comment.content),
                                        ],
                                      ),
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        onPressed: () =>
                                            _deleteComment(comment),
                                        icon: const Icon(
                                          Iconsax.trash,
                                          size: 16,
                                        ),
                                        tooltip: '댓글 삭제',
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('댓글을 불러오지 못했습니다.\n$error'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                if (isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingL,
                      AppTheme.spacingS,
                      AppTheme.spacingL,
                      AppTheme.spacingM,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '댓글을 입력하세요',
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (_canSubmitComment) {
                                _submitComment();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _canSubmitComment ? _submitComment : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.communityColor,
                          ),
                          child: _sendingComment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Iconsax.send_1, size: 18),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingL,
                      AppTheme.spacingS,
                      AppTheme.spacingL,
                      AppTheme.spacingM,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.lock_1, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '댓글 작성은 로그인 후 가능합니다.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/auth/login'),
                            child: const Text('로그인'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
