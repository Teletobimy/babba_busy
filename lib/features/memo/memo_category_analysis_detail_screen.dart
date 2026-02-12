import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../services/ai/ai_api_service.dart';
import '../../shared/providers/auth_provider.dart';

class MemoCategoryAnalysisDetailScreen extends ConsumerStatefulWidget {
  final String analysisId;

  const MemoCategoryAnalysisDetailScreen({super.key, required this.analysisId});

  @override
  ConsumerState<MemoCategoryAnalysisDetailScreen> createState() =>
      _MemoCategoryAnalysisDetailScreenState();
}

class _MemoCategoryAnalysisDetailScreenState
    extends ConsumerState<MemoCategoryAnalysisDetailScreen> {
  Future<MemoCategoryAnalysisResult>? _resultFuture;

  @override
  void initState() {
    super.initState();
    _resultFuture = _load();
  }

  Future<MemoCategoryAnalysisResult> _load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw AiApiException('로그인이 필요합니다.');
    }
    return ref
        .read(aiApiServiceProvider)
        .getMemoCategoryAnalysis(
          userId: user.uid,
          analysisId: widget.analysisId,
        );
  }

  void _refresh() {
    setState(() {
      _resultFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: const Text('카테고리 분석 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Iconsax.refresh),
          ),
        ],
      ),
      body: FutureBuilder<MemoCategoryAnalysisResult>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.warning_2,
                      color: AppColors.coral[500],
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.grayScale[700]),
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

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.document_text,
                      size: 44,
                      color: AppColors.grayScale[500],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '분석 결과가 없습니다.',
                      style: TextStyle(color: AppColors.grayScale[700]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          context.go('/memo/category-analysis/history'),
                      child: const Text('분석 이력 보기'),
                    ),
                  ],
                ),
              ),
            );
          }

          final result = data.result;
          final summary = _readString(result['summary']);
          final keyInsights = _readStringList(result['key_insights']);
          final risks = _readStringList(result['risks']);
          final openQuestions = _readStringList(result['open_questions']);
          final contradictions = _readStringList(result['contradictions']);
          final recommendedTags = _readStringList(result['recommended_tags']);
          final evidence = _readMapList(result['evidence']);
          final actionItems = _readMapList(result['action_items']);
          final confidence = _resolveConfidence(result);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _OverviewCard(
                categoryName: data.categoryName,
                memoCount: data.memoCount,
                confidence: confidence,
                completedAt: data.completedAt ?? data.createdAt,
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TextSection(title: '요약', text: summary),
              ],
              if (keyInsights.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StringListSection(title: '핵심 인사이트', values: keyInsights),
              ],
              if (actionItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ActionItemsSection(items: actionItems),
              ],
              if (risks.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StringListSection(title: '리스크', values: risks),
              ],
              if (openQuestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StringListSection(title: '미해결 질문', values: openQuestions),
              ],
              if (contradictions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StringListSection(title: '상충/모순 포인트', values: contradictions),
              ],
              if (recommendedTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _TagSection(tags: recommendedTags),
              ],
              if (evidence.isNotEmpty) ...[
                const SizedBox(height: 12),
                _EvidenceSection(evidence: evidence),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _readString(dynamic raw) {
  if (raw == null) return '';
  return raw.toString().trim();
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) return const [];
  final values = <String>[];
  for (final item in raw) {
    final value = item.toString().trim();
    if (value.isEmpty || values.contains(value)) continue;
    values.add(value);
  }
  return values;
}

List<Map<String, dynamic>> _readMapList(dynamic raw) {
  if (raw is! List) return const [];
  final values = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map) {
      values.add(Map<String, dynamic>.from(item));
    }
  }
  return values;
}

double? _resolveConfidence(Map<String, dynamic> result) {
  final confidence = result['confidence'];
  if (confidence is num) {
    return confidence.toDouble().clamp(0.0, 1.0).toDouble();
  }

  final quality = result['quality'];
  if (quality is Map) {
    final adjusted = quality['adjusted_confidence'];
    if (adjusted is num) {
      return adjusted.toDouble().clamp(0.0, 1.0).toDouble();
    }
  }
  return null;
}

class _OverviewCard extends StatelessWidget {
  final String categoryName;
  final int memoCount;
  final double? confidence;
  final DateTime? completedAt;

  const _OverviewCard({
    required this.categoryName,
    required this.memoCount,
    required this.confidence,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName.isEmpty ? '전체 메모' : categoryName,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(icon: Iconsax.note_1, text: '$memoCount개 메모'),
              if (confidence != null)
                _MetaPill(
                  icon: Iconsax.chart,
                  text: '신뢰도 ${(confidence! * 100).toStringAsFixed(0)}%',
                ),
              if (completedAt != null)
                _MetaPill(
                  icon: Iconsax.calendar_1,
                  text: DateFormat('yyyy.MM.dd HH:mm').format(completedAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final String title;
  final String text;

  const _TextSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(color: AppColors.grayScale[700], height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StringListSection extends StatelessWidget {
  final String title;
  final List<String> values;

  const _StringListSection({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Iconsax.tick_circle,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: AppColors.grayScale[700],
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItemsSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _ActionItemsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('실행 항목', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...items.map((item) {
            final task = _readString(item['task']);
            final priority = _readString(item['priority']).toLowerCase();
            final ownerHint = _readString(item['owner_hint']);
            final dueHint = _readString(item['due_hint']);
            if (task.isEmpty) return const SizedBox.shrink();

            final (chipBg, chipFg, chipLabel) = switch (priority) {
              'high' => (AppColors.coral[100]!, AppColors.coral[700]!, '높음'),
              'low' => (
                AppColors.grayScale[200]!,
                AppColors.grayScale[700]!,
                '낮음',
              ),
              _ => (AppColors.sage[100]!, AppColors.sage[700]!, '중간'),
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.grayScale[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task,
                          style: TextStyle(
                            color: AppColors.grayScale[800],
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          chipLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: chipFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (ownerHint.isNotEmpty || dueHint.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (ownerHint.isNotEmpty) '담당: $ownerHint',
                        if (dueHint.isNotEmpty) '기한: $dueHint',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayScale[600],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final List<String> tags;

  const _TagSection({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('추천 태그', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

class _EvidenceSection extends StatelessWidget {
  final List<Map<String, dynamic>> evidence;

  const _EvidenceSection({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('근거', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...evidence.take(20).map((item) {
            final memoId = _readString(item['memo_id']);
            final quote = _readString(item['quote']);
            final point = _readString(item['point']);
            if (quote.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.grayScale[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote,
                    style: TextStyle(
                      color: AppColors.grayScale[800],
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (point.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      point,
                      style: TextStyle(
                        color: AppColors.grayScale[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (memoId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'memo_id: $memoId',
                      style: TextStyle(
                        color: AppColors.grayScale[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
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
