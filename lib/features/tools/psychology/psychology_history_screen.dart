import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/psychology_test_result.dart';
import '../../../shared/providers/psychology_result_provider.dart';
import '../../../shared/providers/auth_provider.dart';

/// 심리검사 이력 화면
class PsychologyHistoryScreen extends ConsumerWidget {
  const PsychologyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final resultsAsync = ref.watch(psychologyResultsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/tools/psychology');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.grayScale[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left),
            onPressed: () => context.go('/tools/psychology'),
          ),
          title: const Text('검사 이력'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: user == null
            ? _buildLoginRequired(context)
            : resultsAsync.when(
                data: (results) => results.isEmpty
                    ? _buildEmptyState(context)
                    : _buildResultsList(context, results),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.warning_2,
                        size: 48,
                        color: AppColors.grayScale[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '이력을 불러올 수 없습니다',
                        style: TextStyle(color: AppColors.grayScale[600]),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.lock_1, size: 48, color: AppColors.grayScale[400]),
            const SizedBox(height: 12),
            Text(
              '로그인이 필요합니다',
              style: TextStyle(fontSize: 16, color: AppColors.grayScale[700]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/auth/login'),
              child: const Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document, size: 64, color: AppColors.grayScale[300]),
          const SizedBox(height: 16),
          Text(
            '아직 검사 이력이 없습니다',
            style: TextStyle(fontSize: 16, color: AppColors.grayScale[500]),
          ),
          const SizedBox(height: 8),
          Text(
            '심리검사를 진행하면 여기에 기록됩니다',
            style: TextStyle(fontSize: 14, color: AppColors.grayScale[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
    BuildContext context,
    List<PsychologyTestResult> results,
  ) {
    // 날짜별 그룹화
    final groupedResults = <String, List<PsychologyTestResult>>{};
    for (final result in results) {
      final dateKey = DateFormat('yyyy년 M월').format(result.completedAt);
      groupedResults.putIfAbsent(dateKey, () => []).add(result);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: groupedResults.length,
      itemBuilder: (context, index) {
        final dateKey = groupedResults.keys.elementAt(index);
        final monthResults = groupedResults[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: index > 0 ? 16 : 0),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grayScale[600],
                ),
              ),
            ),
            ...monthResults.asMap().entries.map((entry) {
              return _buildResultCard(context, entry.value)
                  .animate()
                  .fadeIn(delay: (index * 50 + entry.key * 30).ms)
                  .slideY(begin: 0.1);
            }),
          ],
        );
      },
    );
  }

  Widget _buildResultCard(BuildContext context, PsychologyTestResult result) {
    final color = AppColors.getTestColor(result.testType);
    final dateFormat = DateFormat('M월 d일 HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            // TODO: 결과 상세 화면으로 이동
            _showResultDialog(context, result);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      result.testTypeIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.testTypeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(result.completedAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.grayScale[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  color: AppColors.grayScale[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context, PsychologyTestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(result.testTypeIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.testTypeName,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '완료일: ${DateFormat('yyyy년 M월 d일 HH:mm').format(result.completedAt)}',
                style: TextStyle(color: AppColors.grayScale[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '결과 요약',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildResultSummary(result),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary(PsychologyTestResult result) {
    // 결과 데이터를 간단히 표시
    final resultData = result.result;

    if (resultData.isEmpty) {
      return Text(
        '결과 데이터가 없습니다',
        style: TextStyle(color: AppColors.grayScale[500]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: resultData.entries.take(5).map((entry) {
        final value = entry.value;
        final displayValue = value is double
            ? value.toStringAsFixed(1)
            : value.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• ${entry.key}: $displayValue',
            style: TextStyle(color: AppColors.grayScale[700], fontSize: 14),
          ),
        );
      }).toList(),
    );
  }
}
