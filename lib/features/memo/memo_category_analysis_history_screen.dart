import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/ai/ai_api_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/smart_provider.dart';

class MemoCategoryAnalysisHistoryScreen extends ConsumerStatefulWidget {
  const MemoCategoryAnalysisHistoryScreen({super.key});

  @override
  ConsumerState<MemoCategoryAnalysisHistoryScreen> createState() =>
      _MemoCategoryAnalysisHistoryScreenState();
}

class _MemoCategoryAnalysisHistoryScreenState
    extends ConsumerState<MemoCategoryAnalysisHistoryScreen> {
  String? _selectedCategoryId;
  Future<List<MemoCategoryAnalysisHistoryItem>>? _historyFuture;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<MemoCategoryAnalysisHistoryItem>> _loadHistory() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return const [];
    return ref
        .read(aiApiServiceProvider)
        .getMemoCategoryAnalysisHistory(
          userId: user.uid,
          categoryId: _selectedCategoryId,
          limit: 50,
        );
  }

  void _refresh() {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  bool _isCompletedStatus(String status) =>
      status.toLowerCase().trim() == 'completed';

  bool _isInProgressStatus(String status) {
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending' || normalized == 'processing';
  }

  bool _isFailedStatus(String status) =>
      status.toLowerCase().trim() == 'failed';

  void _syncAutoRefresh(List<MemoCategoryAnalysisHistoryItem> history) {
    final shouldAutoRefresh = history.any(
      (item) => _isInProgressStatus(item.status),
    );

    if (shouldAutoRefresh) {
      _autoRefreshTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
        if (!mounted) return;
        _refresh();
      });
      return;
    }

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(smartMemoCategoriesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: const Text('카테고리 분석 이력'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Iconsax.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('전체'),
                          selected: _selectedCategoryId == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategoryId = null;
                              _historyFuture = _loadHistory();
                            });
                          },
                        ),
                      ),
                      ...categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category.name),
                            selected: _selectedCategoryId == category.id,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategoryId = category.id;
                                _historyFuture = _loadHistory();
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<MemoCategoryAnalysisHistoryItem>>(
                    future: _historyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        _autoRefreshTimer?.cancel();
                        _autoRefreshTimer = null;
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Iconsax.warning_2,
                                  color: AppColors.coral[500],
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '분석 이력을 불러오지 못했습니다.',
                                  style: TextStyle(
                                    color: AppColors.grayScale[700],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _refresh,
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final history = snapshot.data ?? const [];
                      if (history.isEmpty) {
                        _autoRefreshTimer?.cancel();
                        _autoRefreshTimer = null;
                        return Center(
                          child: Text(
                            '분석 이력이 없습니다.',
                            style: TextStyle(color: AppColors.grayScale[500]),
                          ),
                        );
                      }

                      _syncAutoRefresh(history);

                      return RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final completedAt =
                                item.completedAt ?? item.createdAt;
                            final confidence = item.confidence;
                            final isCompleted = _isCompletedStatus(item.status);
                            final canOpenDetail =
                                isCompleted && item.analysisId.isNotEmpty;
                            final isInProgress = _isInProgressStatus(
                              item.status,
                            );
                            final isFailed = _isFailedStatus(item.status);

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: canOpenDetail
                                    ? () {
                                        context.push(
                                          '/memo/category-analysis/${item.analysisId}',
                                        );
                                      }
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.categoryName.isEmpty
                                                  ? '전체 메모'
                                                  : item.categoryName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          _StatusChip(status: item.status),
                                        ],
                                      ),
                                      if (item.summary.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          item.summary,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.grayScale[700],
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                      if (!canOpenDetail) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          isInProgress
                                              ? '분석 진행 중입니다. 완료되면 자동으로 새로고침됩니다.'
                                              : isFailed
                                              ? '분석 실패 항목입니다. 메모 화면에서 다시 요청해 주세요.'
                                              : '결과 준비 중입니다.',
                                          style: TextStyle(
                                            color: AppColors.grayScale[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _MetaPill(
                                            icon: Iconsax.note_1,
                                            text: '${item.memoCount}개 메모',
                                          ),
                                          if (completedAt != null)
                                            _MetaPill(
                                              icon: Iconsax.calendar_1,
                                              text: DateFormat(
                                                'M월 d일 HH:mm',
                                              ).format(completedAt),
                                            ),
                                          if (confidence != null)
                                            _MetaPill(
                                              icon: Iconsax.chart,
                                              text:
                                                  '신뢰도 ${(confidence * 100).toStringAsFixed(0)}%',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();
    final (bg, fg, label) = switch (normalized) {
      'completed' => (AppColors.sage[100]!, AppColors.sage[700]!, '완료'),
      'failed' => (AppColors.coral[100]!, AppColors.coral[700]!, '실패'),
      'processing' || 'pending' => (
        AppColors.grayScale[200]!,
        AppColors.grayScale[700]!,
        '진행 중',
      ),
      _ => (AppColors.grayScale[200]!, AppColors.grayScale[700]!, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.grayScale[100],
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.grayScale[600]),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: AppColors.grayScale[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
