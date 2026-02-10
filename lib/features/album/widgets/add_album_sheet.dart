import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/album_provider.dart';
import '../../../shared/providers/group_provider.dart';
import '../../../shared/models/album.dart';
import 'album_share_sheet.dart';

/// 앨범 추가 바텀 시트
class AddAlbumSheet extends ConsumerStatefulWidget {
  const AddAlbumSheet({super.key});

  @override
  ConsumerState<AddAlbumSheet> createState() => _AddAlbumSheetState();
}

class _AddAlbumSheetState extends ConsumerState<AddAlbumSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeNameController = TextEditingController();
  AlbumType _selectedType = AlbumType.moment;
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedPhotoPaths = [];
  List<String> _selectedGroupIds = [];
  bool _hasLocation = false;
  bool _isLoading = false;

  // 임시 좌표 (실제로는 지도에서 선택하거나 현재 위치 사용)
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    // 기본적으로 현재 그룹 선택
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentGroupId = ref.read(selectedGroupIdProvider);
      if (currentGroupId != null) {
        setState(() {
          _selectedGroupIds = [currentGroupId];
        });
      }
    });
  }

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

  double _uploadProgress = 0.0;

  Future<void> _handleAdd() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final albumService = ref.read(albumServiceProvider);

      // Firebase Storage에 이미지 업로드
      List<String> photoUrls = [];
      if (_selectedPhotoPaths.isNotEmpty) {
        photoUrls = await albumService.uploadPhotos(
          _selectedPhotoPaths,
          onProgress: (progress) {
            if (mounted) {
              setState(() => _uploadProgress = progress);
            }
          },
        );
      }

      await albumService.addAlbum(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            date: _selectedDate,
            photoUrls: photoUrls,
            sharedGroups: _selectedGroupIds,
            visibility: _selectedGroupIds.isEmpty
                ? AlbumVisibility.private
                : AlbumVisibility.shared,
            albumType: _selectedType,
            hasLocation: _hasLocation,
            latitude: _hasLocation ? _latitude : null,
            longitude: _hasLocation ? _longitude : null,
            placeName: _hasLocation && _placeNameController.text.trim().isNotEmpty
                ? _placeNameController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('앨범 저장 실패: $e')),
        );
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

  void _showShareSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlbumShareSheet(
        selectedGroupIds: _selectedGroupIds,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedGroupIds = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberships = ref.watch(filteredUserMembershipsProvider).value ?? [];

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
              '새 앨범',
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
                hintText: '앨범 제목',
                prefixIcon: Icon(Iconsax.text),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 앨범 타입
            Text(
              '앨범 유형',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AlbumType.values.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
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
                      type.label,
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

            // 공유 설정
            GestureDetector(
              onTap: _showShareSheet,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedGroupIds.isEmpty ? Iconsax.lock : Iconsax.share,
                      size: 20,
                      color: _selectedGroupIds.isNotEmpty
                          ? AppColors.memoryColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedGroupIds.isEmpty
                          ? Text(
                              '나만 보기',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedGroupIds.length}개 그룹에 공유',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.memoryColor,
                                      ),
                                ),
                                Text(
                                  memberships
                                      .where((m) =>
                                          _selectedGroupIds.contains(m.groupId))
                                      .map((m) => m.groupName)
                                      .join(', '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                    const Icon(Iconsax.arrow_right_3, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // 위치 정보 토글
            Row(
              children: [
                Checkbox(
                  value: _hasLocation,
                  onChanged: (value) {
                    setState(() {
                      _hasLocation = value ?? false;
                      if (!_hasLocation) {
                        _placeNameController.clear();
                        _latitude = null;
                        _longitude = null;
                      }
                    });
                  },
                  activeColor: AppColors.memoryColor,
                ),
                Text(
                  '위치 정보 추가',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            // 장소명 (위치 정보 활성화 시)
            if (_hasLocation) ...[
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                controller: _placeNameController,
                decoration: const InputDecoration(
                  hintText: '장소 이름',
                  prefixIcon: Icon(Iconsax.location),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingM),

            // 설명
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '앨범 설명 (선택)',
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
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          if (_selectedPhotoPaths.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '업로드 ${(_uploadProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ],
                      )
                    : const Text('앨범 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
