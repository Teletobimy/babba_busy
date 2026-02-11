import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/person.dart';
import '../../../shared/providers/people_provider.dart';

const Color peopleColor = Color(0xFF5B8DEF);

class AddPersonSheet extends ConsumerStatefulWidget {
  final Person? initialPerson;

  const AddPersonSheet({super.key, this.initialPerson});

  @override
  ConsumerState<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _personalityController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _birthday;
  String? _mbti;
  String? _relationship;
  final List<String> _tags = [];
  bool _isSaving = false;

  bool get _isEditMode => widget.initialPerson != null;

  @override
  void initState() {
    super.initState();
    final person = widget.initialPerson;
    if (person == null) return;

    _nameController.text = person.name;
    _phoneController.text = person.phone ?? '';
    _emailController.text = person.email ?? '';
    _addressController.text = person.address ?? '';
    _companyController.text = person.company ?? '';
    _personalityController.text = person.personality ?? '';
    _noteController.text = person.note ?? '';
    _birthday = person.birthday;
    _mbti = person.mbti;
    _relationship = person.relationship;
    _tags.addAll(person.tags);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _personalityController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 핸들
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // 타이틀
                  Text(
                    _isEditMode ? '사람 정보 수정' : '새 사람 추가',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // 이름 (필수)
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '이름 *',
                      prefixIcon: const Icon(Iconsax.user),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이름을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 관계
                  DropdownButtonFormField<String>(
                    initialValue: _relationship,
                    decoration: InputDecoration(
                      labelText: '관계',
                      prefixIcon: const Icon(Iconsax.people),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('선택 안함')),
                      ...PersonRelationship.all.map((rel) {
                        return DropdownMenuItem(
                          value: rel,
                          child: Text(PersonRelationship.getLabel(rel)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _relationship = value);
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 생일
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Iconsax.cake),
                    title: Text(
                      _birthday != null
                          ? DateFormat('yyyy년 M월 d일').format(_birthday!)
                          : '생일 선택',
                    ),
                    trailing: _birthday != null
                        ? IconButton(
                            icon: const Icon(Iconsax.close_circle),
                            onPressed: () => setState(() => _birthday = null),
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _birthday ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _birthday = date);
                      }
                    },
                  ),
                  const Divider(),

                  // MBTI
                  DropdownButtonFormField<String>(
                    initialValue: _mbti,
                    decoration: InputDecoration(
                      labelText: 'MBTI',
                      prefixIcon: const Icon(Iconsax.personalcard),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('선택 안함')),
                      ...MbtiType.all.map((mbti) {
                        return DropdownMenuItem(value: mbti, child: Text(mbti));
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _mbti = value);
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 전화번호
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: '전화번호',
                      prefixIcon: const Icon(Iconsax.call),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 이메일
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: '이메일',
                      prefixIcon: const Icon(Iconsax.sms),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 회사/학교
                  TextFormField(
                    controller: _companyController,
                    decoration: InputDecoration(
                      labelText: '회사/학교',
                      prefixIcon: const Icon(Iconsax.building),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 주소
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: '주소',
                      prefixIcon: const Icon(Iconsax.location),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 성격/특징
                  TextFormField(
                    controller: _personalityController,
                    decoration: InputDecoration(
                      labelText: '성격/특징',
                      prefixIcon: const Icon(Iconsax.heart),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 메모
                  TextFormField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: '메모',
                      prefixIcon: const Icon(Iconsax.note),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 태그
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            labelText: '태그 추가',
                            prefixIcon: const Icon(Iconsax.hashtag),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                          ),
                          onFieldSubmitted: _addTag,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _addTag(_tagController.text),
                        icon: const Icon(Iconsax.add_circle),
                        color: peopleColor,
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() => _tags.remove(tag));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingL),

                  // 저장 버튼
                  ElevatedButton(
                    onPressed: _isSaving ? null : _savePerson,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peopleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditMode ? '수정하기' : '저장하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final peopleService = ref.read(peopleServiceProvider);
      final normalizedTags = _tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      if (_isEditMode) {
        final origin = widget.initialPerson!;
        final updated = Person(
          id: origin.id,
          familyId: origin.familyId,
          name: _nameController.text.trim(),
          profilePhotoUrl: origin.profilePhotoUrl,
          birthday: _birthday,
          mbti: _mbti,
          phone: _optional(_phoneController.text),
          email: _optional(_emailController.text),
          address: _optional(_addressController.text),
          personality: _optional(_personalityController.text),
          relationship: _relationship,
          company: _optional(_companyController.text),
          note: _optional(_noteController.text),
          events: origin.events,
          carePriority: origin.carePriority,
          lastContactAt: origin.lastContactAt,
          lastCareActionAt: origin.lastCareActionAt,
          nextCareDueAt: origin.nextCareDueAt,
          lifeContextSummary: origin.lifeContextSummary,
          lifeEvents: origin.lifeEvents,
          giftPreference: origin.giftPreference,
          giftHistory: origin.giftHistory,
          assistantSnapshot: origin.assistantSnapshot,
          customFields: origin.customFields,
          tags: normalizedTags,
          createdAt: origin.createdAt,
          createdBy: origin.createdBy,
        );
        await peopleService.updatePerson(updated);
      } else {
        final person = Person(
          id: '',
          familyId: '',
          name: _nameController.text.trim(),
          birthday: _birthday,
          mbti: _mbti,
          phone: _optional(_phoneController.text),
          email: _optional(_emailController.text),
          address: _optional(_addressController.text),
          personality: _optional(_personalityController.text),
          relationship: _relationship,
          company: _optional(_companyController.text),
          note: _optional(_noteController.text),
          tags: normalizedTags,
          createdAt: DateTime.now(),
          createdBy: '',
        );
        await peopleService.addPerson(person);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? '${_nameController.text}님 정보가 수정되었습니다'
                : '${_nameController.text}님이 추가되었습니다',
          ),
          backgroundColor: peopleColor,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: AppColors.errorLight,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
