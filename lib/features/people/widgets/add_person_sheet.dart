import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/person.dart';

const Color peopleColor = Color(0xFF5B8DEF);

class AddPersonSheet extends ConsumerStatefulWidget {
  const AddPersonSheet({super.key});

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
                    '새 사람 추가',
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('선택 안함'),
                      ),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('선택 안함'),
                      ),
                      ...MbtiType.all.map((mbti) {
                        return DropdownMenuItem(
                          value: mbti,
                          child: Text(mbti),
                        );
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
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
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
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
                    onPressed: _savePerson,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peopleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: const Text(
                      '저장하기',
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

  void _savePerson() {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Firebase에 저장
    // 데모 모드에서는 그냥 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_nameController.text}님이 추가되었습니다'),
        backgroundColor: peopleColor,
      ),
    );
    Navigator.of(context).pop();
  }
}
