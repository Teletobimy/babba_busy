import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/memory_provider.dart';

/// 추억 추가 바텀 시트
class AddMemorySheet extends ConsumerStatefulWidget {
  const AddMemorySheet({super.key});

  @override
  ConsumerState<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends ConsumerState<AddMemorySheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeNameController = TextEditingController();
  String _selectedCategory = 'daily';
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedPhotoPaths = [];
  bool _isLoading = false;

  // 임시 좌표 (실제로는 지도에서 선택하거나 현재 위치 사용)
  final double _latitude = 37.5665;
  final double _longitude = 126.9780;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedPhotoPaths.addAll(images.map((e) => e.path));
      });
    }
  }

  Future<void> _handleAdd() async {
    if (_titleController.text.trim().isEmpty) return;
    if (_placeNameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final memoryService = ref.read(memoryServiceProvider);
      
      // 실제로는 Firebase Storage에 이미지 업로드 후 URL 획득
      // 여기서는 로컬 경로를 그대로 사용 (데모용)
      final photoUrls = _selectedPhotoPaths;

      await memoryService.addMemory(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        placeName: _placeNameController.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        photoUrls: photoUrls,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppTheme.spacingL,
          right: AppTheme.spacingL,
          top: AppTheme.spacingM,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 핸들바
            Center(
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
            const SizedBox(height: AppTheme.spacingM),

            // 타이틀
            Text(
              '새 추억',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 사진 추가
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppColors.memoryColor.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedPhotoPaths.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.gallery_add,
                            size: 32,
                            color: AppColors.memoryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '사진 추가',
                            style: TextStyle(
                              color: AppColors.memoryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        itemCount: _selectedPhotoPaths.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _selectedPhotoPaths.length) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.memoryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Iconsax.add,
                                color: AppColors.memoryColor,
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.memoryColor.withValues(alpha: 0.2),
                                ),
                                child: const Icon(
                                  Iconsax.image,
                                  color: AppColors.memoryColor,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedPhotoPaths.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 제목
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '추억 제목',
                prefixIcon: Icon(Iconsax.text),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 장소명
            TextField(
              controller: _placeNameController,
              decoration: const InputDecoration(
                hintText: '장소 이름',
                prefixIcon: Icon(Iconsax.location),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 카테고리
            Text(
              '카테고리',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MemoryCategory.all.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.memoryColor
                          : AppColors.memoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      MemoryCategory.getLabel(category),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.memoryColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 날짜
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('yyyy년 M월 d일').format(_selectedDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 설명
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '추억에 대한 설명 (선택)',
                prefixIcon: Icon(Iconsax.note_1),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // 추가 버튼
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.memoryColor,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('추억 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
