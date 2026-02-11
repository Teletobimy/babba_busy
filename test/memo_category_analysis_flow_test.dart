import 'package:babba/features/tools/business/widgets/request_accepted_screen.dart';
import 'package:babba/services/ai/ai_api_service.dart';
import 'package:babba/shared/models/analysis_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memo category analysis flow', () {
    test('routes memo analysis completion to detail when resultId exists', () {
      final now = DateTime(2026, 2, 11);
      final job = AnalysisJob(
        id: 'job1',
        userId: 'u1',
        jobType: AnalysisJobType.memoCategoryAnalysis,
        status: AnalysisJobStatus.completed,
        input: const {},
        progress: AnalysisJobProgress(
          currentStep: 5,
          totalSteps: 5,
          percentage: 100,
        ),
        resultId: 'analysis-123',
        createdAt: now,
        updatedAt: now,
      );

      final route = resolveCompletedAnalysisRoute(job);

      expect(route, '/memo/category-analysis/analysis-123');
    });

    test(
      'routes memo analysis completion to history when resultId missing',
      () {
        final now = DateTime(2026, 2, 11);
        final job = AnalysisJob(
          id: 'job2',
          userId: 'u1',
          jobType: AnalysisJobType.memoCategoryAnalysis,
          status: AnalysisJobStatus.completed,
          input: const {},
          progress: AnalysisJobProgress(
            currentStep: 5,
            totalSteps: 5,
            percentage: 100,
          ),
          createdAt: now,
          updatedAt: now,
        );

        final route = resolveCompletedAnalysisRoute(job);

        expect(route, '/memo/category-analysis/history');
      },
    );

    test('parses memo category analysis result payload safely', () {
      final result = MemoCategoryAnalysisResult.fromJson({
        'analysis_id': 'a1',
        'category_id': 'c1',
        'category_name': '업무',
        'memo_count': 12,
        'result': {
          'summary': '요약',
          'key_insights': ['인사이트 1'],
        },
        'status': 'completed',
        'created_at': '2026-02-11T01:00:00Z',
        'completed_at': '2026-02-11T01:02:00Z',
      });

      expect(result.analysisId, 'a1');
      expect(result.categoryId, 'c1');
      expect(result.categoryName, '업무');
      expect(result.memoCount, 12);
      expect(result.status, 'completed');
      expect(result.result['summary'], '요약');
      expect(result.completedAt, isNotNull);
    });

    test('parses memo category analysis history payload safely', () {
      final item = MemoCategoryAnalysisHistoryItem.fromJson({
        'analysis_id': 'a2',
        'category_id': null,
        'category_name': '전체 메모',
        'memo_count': 30,
        'summary': '핵심 요약',
        'confidence': 0.82,
        'status': 'processing',
        'job_id': 'j2',
        'created_at': '2026-02-11T00:50:00Z',
      });

      expect(item.analysisId, 'a2');
      expect(item.categoryId, isNull);
      expect(item.memoCount, 30);
      expect(item.summary, '핵심 요약');
      expect(item.confidence, closeTo(0.82, 0.0001));
      expect(item.status, 'processing');
      expect(item.jobId, 'j2');
      expect(item.createdAt, isNotNull);
    });
  });
}
