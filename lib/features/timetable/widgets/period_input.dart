import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../timetable_screen.dart';

/// 교시 시간 설정 시트
class PeriodSettingsSheet extends StatelessWidget {
  const PeriodSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                '교시 시간 설정',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '한국 학교 기본 시간표가 적용되어 있습니다',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: defaultPeriods.length,
                  itemBuilder: (context, index) {
                    final period = defaultPeriods[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(period['period']!),
                      subtitle: Text('${period['start']} ~ ${period['end']}'),
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
