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

class CommunityHubScreen extends ConsumerStatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  ConsumerState<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends ConsumerState<CommunityHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateCommunitySheet() async {
    final communityId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateCommunitySheet(),
    );

    if (communityId != null && communityId.isNotEmpty && mounted) {
      context.push('/tools/community/$communityId');
    }
  }

  List<CommunitySpace> _filterCommunities(List<CommunitySpace> communities) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return communities;

    return communities.where((community) {
      return community.name.toLowerCase().contains(query) ||
          community.description.toLowerCase().contains(query) ||
          community.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(communitiesProvider);
    final isLoggedIn = ref.watch(currentUserProvider) != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noticeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        actions: [
          IconButton(
            onPressed: isLoggedIn
                ? _openCreateCommunitySheet
                : () => context.push('/auth/login'),
            icon: Icon(isLoggedIn ? Iconsax.add : Iconsax.login_1),
            tooltip: isLoggedIn ? '커뮤니티 만들기' : '로그인',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoggedIn ? _openCreateCommunitySheet : null,
        backgroundColor: AppColors.communityColor,
        foregroundColor: Colors.white,
        icon: Icon(isLoggedIn ? Iconsax.add : Iconsax.lock_1),
        label: Text(isLoggedIn ? '새 커뮤니티' : '로그인 후 생성'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppTheme.spacingL,
              AppTheme.spacingM,
              AppTheme.spacingL,
              AppTheme.spacingS,
            ),
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppColors.communityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppColors.communityColor.withValues(alpha: 0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '레딧처럼 테마별 커뮤니티를 만들고 운영하세요',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  '관심사별로 여러 게시판을 만들고 글/댓글로 소통할 수 있습니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
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
                      '지금은 읽기 전용입니다. 글 작성은 로그인 후 가능합니다.',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingL,
              0,
              AppTheme.spacingL,
              AppTheme.spacingS,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Iconsax.search_normal),
                hintText: '커뮤니티 검색 (이름/설명/태그)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
              ),
            ),
          ),
          Expanded(
            child: communitiesAsync.when(
              data: (communities) {
                final filtered = _filterCommunities(communities);
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.people,
                            size: 56,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            communities.isEmpty
                                ? '아직 커뮤니티가 없습니다'
                                : '검색 결과가 없습니다',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Text(
                            communities.isEmpty
                                ? '첫 커뮤니티를 만들어 시작해보세요.'
                                : '다른 검색어를 시도해보세요.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                    final community = filtered[index];
                    return _CommunityCard(
                      community: community,
                      onTap: () =>
                          context.push('/tools/community/${community.id}'),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.spacingS),
                  itemCount: filtered.length,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Text('커뮤니티를 불러오지 못했습니다.\n$error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunitySpace community;
  final VoidCallback onTap;

  const _CommunityCard({required this.community, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          padding: const EdgeInsets.all(AppTheme.spacingM),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    DateFormat('yy.MM.dd').format(community.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                community.description.isEmpty ? '설명 없음' : community.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: community.tags.isEmpty
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '#일반',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ]
                    : community.tags
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCommunitySheet extends ConsumerStatefulWidget {
  const _CreateCommunitySheet();

  @override
  ConsumerState<_CreateCommunitySheet> createState() =>
      _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends ConsumerState<_CreateCommunitySheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
    setState(() => _submitting = true);

    try {
      final communityId = await ref
          .read(communityServiceProvider)
          .createCommunity(
            name: _nameController.text,
            description: _descriptionController.text,
            tags: _parseTags(_tagsController.text),
          );
      if (communityId == null) {
        throw Exception('로그인 후 이용해주세요.');
      }

      if (!mounted) return;
      Navigator.of(context).pop(communityId);
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '새 커뮤니티 만들기',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: _nameController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: '커뮤니티 이름 *',
                    hintText: '예: 게임 토론방, 창업 피드백',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '설명',
                    hintText: '이 커뮤니티에서 어떤 대화를 하는지 적어주세요',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '태그 (쉼표 구분)',
                    hintText: '예: 게임, rpg, 콘솔',
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
                        : const Icon(Iconsax.add),
                    label: Text(_submitting ? '생성 중...' : '생성하기'),
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
