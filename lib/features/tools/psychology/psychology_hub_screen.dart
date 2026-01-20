import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// 심리검사 허브 화면
class PsychologyHubScreen extends ConsumerWidget {
  const PsychologyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.grayScale[50],
      appBar: AppBar(
        title: const Text('심리검사'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => context.push('/tools/psychology/history'),
            icon: const Icon(Iconsax.document_text),
            tooltip: '검사 이력',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Text(
              '🧠 나를 더 잘 이해하기',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '과학적인 심리검사로 나의 성격, 관계 패턴, 마음 상태를 알아보세요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grayScale[600],
                  ),
            ),
            const SizedBox(height: 24),

            // 성격 검사 섹션
            _buildSectionTitle(context, '성격 검사', Iconsax.user_octagon),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'big5',
              title: 'Big5 성격검사',
              subtitle: '성격의 5가지 주요 요인을 측정합니다',
              icon: '🎭',
              duration: '약 10분',
              questionCount: 25,
              color: AppColors.coral,
            ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'mbti',
              title: 'MBTI 성격유형',
              subtitle: '16가지 성격 유형 중 나의 유형을 알아봅니다',
              icon: '🧩',
              duration: '약 8분',
              questionCount: 20,
              color: AppColors.lavender,
            ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.1),
            const SizedBox(height: 24),

            // 관계 검사 섹션
            _buildSectionTitle(context, '관계 검사', Iconsax.heart),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'attachment',
              title: '애착유형 검사',
              subtitle: '대인관계에서의 애착 패턴을 파악합니다',
              icon: '💕',
              duration: '약 8분',
              questionCount: 20,
              color: AppColors.getTestColor('attachment'),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'love_language',
              title: '사랑의 언어',
              subtitle: '나의 사랑 표현/수용 방식을 알아봅니다',
              icon: '💝',
              duration: '약 6분',
              questionCount: 15,
              color: AppColors.getTestColor('love_language'),
            ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.1),
            const SizedBox(height: 24),

            // 마음 건강 검사 섹션
            _buildSectionTitle(context, '마음 건강', Iconsax.health),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'stress',
              title: '스트레스 지수 (PSS-10)',
              subtitle: '최근 한 달간의 스트레스 수준을 측정합니다',
              icon: '😰',
              duration: '약 4분',
              questionCount: 10,
              color: AppColors.getTestColor('stress'),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'anxiety',
              title: '불안 선별검사 (GAD-7)',
              subtitle: '범불안장애 선별을 위한 표준화된 검사입니다',
              icon: '😟',
              duration: '약 3분',
              questionCount: 7,
              color: AppColors.getTestColor('anxiety'),
              warning: true,
            ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1),
            const SizedBox(height: 12),
            _buildTestCard(
              context,
              testType: 'depression',
              title: '우울 선별검사 (PHQ-9)',
              subtitle: '우울증 선별을 위한 표준화된 검사입니다',
              icon: '😔',
              duration: '약 4분',
              questionCount: 9,
              color: AppColors.getTestColor('depression'),
              warning: true,
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
            const SizedBox(height: 32),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.grayScale[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    color: AppColors.grayScale[500],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '이 검사들은 자기 이해를 돕기 위한 것이며, 전문적인 진단을 대체하지 않습니다.',
                      style: TextStyle(
                        color: AppColors.grayScale[600],
                        fontSize: 13,
                      ),
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

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.grayScale[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildTestCard(
    BuildContext context, {
    required String testType,
    required String title,
    required String subtitle,
    required String icon,
    required String duration,
    required int questionCount,
    required MaterialColor color,
    bool warning = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          context.push('/tools/psychology/test/$testType');
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (warning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '선별용',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.grayScale[500],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Iconsax.clock,
                          size: 14,
                          color: AppColors.grayScale[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: TextStyle(
                            color: AppColors.grayScale[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Iconsax.document,
                          size: 14,
                          color: AppColors.grayScale[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$questionCount문항',
                          style: TextStyle(
                            color: AppColors.grayScale[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                color: AppColors.grayScale[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
