import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/people_provider.dart';
import '../../shared/models/person.dart';
import '../../shared/services/contact_import_service.dart';
import 'widgets/add_person_sheet.dart';
import 'widgets/person_card.dart';
import 'widgets/person_detail_sheet.dart';

/// 사람들 탭 컬러 -- AppColors.peopleColor 사용

enum _ContactImportMode { single, all }

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(displayPeopleProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedRelationship = ref.watch(selectedRelationshipFilterProvider);
    final upcomingBirthdays = ref.watch(upcomingBirthdaysProvider);
    final topCareTargets = ref.watch(topCareTargetsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Column(
          children: [
            // 검색 바
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: TextField(
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
                decoration: InputDecoration(
                  hintText: '이름, 전화번호, 회사, 태그로 검색',
                  prefixIcon: const Icon(Iconsax.search_normal_1, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle, size: 20),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark
                      : AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // 관계 필터
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
              ),
              child: Row(
                children: [
                  _RelationshipChip(
                    label: '전체',
                    isSelected: selectedRelationship == null,
                    onTap: () {
                      ref
                              .read(selectedRelationshipFilterProvider.notifier)
                              .state =
                          null;
                    },
                  ),
                  const SizedBox(width: 8),
                  ...PersonRelationship.all.map((rel) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RelationshipChip(
                        label: PersonRelationship.getLabel(rel),
                        isSelected: selectedRelationship == rel,
                        onTap: () {
                          ref
                                  .read(
                                    selectedRelationshipFilterProvider.notifier,
                                  )
                                  .state =
                              rel;
                        },
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
            const SizedBox(height: AppTheme.spacingM),

            // 다가오는 생일 (있을 경우)
            if (upcomingBirthdays.isNotEmpty && selectedRelationship == null)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.peopleColor.withValues(alpha: 0.15),
                      AppColors.birthdayCountdown.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.cake,
                          size: 18,
                          color: AppColors.birthdayCountdown,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '다가오는 생일',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.birthdayCountdown),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: upcomingBirthdays.length.clamp(0, 5),
                        itemBuilder: (context, index) {
                          final person = upcomingBirthdays[index];
                          final daysLeft = person.daysUntilBirthday ?? 0;
                          return GestureDetector(
                            onTap: () => _showPersonDetail(context, person),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.peopleColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Text(
                                      person.name.isNotEmpty ? person.name[0] : '?',
                                      style: TextStyle(
                                        color: AppColors.peopleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        daysLeft == 0 ? '오늘!' : 'D-$daysLeft',
                                        style: TextStyle(
                                          color: daysLeft <= 7
                                              ? AppColors.birthdayCountdown
                                              : AppColors.peopleColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            if (upcomingBirthdays.isNotEmpty && selectedRelationship == null)
              const SizedBox(height: AppTheme.spacingM),

            // 챙김 우선순위 TOP 3
            if (selectedRelationship == null &&
                searchQuery.isEmpty &&
                topCareTargets.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingL,
                ),
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppColors.peopleColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.star_1,
                          size: 18,
                          color: AppColors.actionEmail,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '지금 챙기면 좋은 사람',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...topCareTargets.map((target) {
                      return InkWell(
                        onTap: () => _showPersonDetail(context, target.person),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.peopleColor.withValues(
                                  alpha: 0.15,
                                ),
                                child: Text(
                                  target.person.name.isNotEmpty ? target.person.name[0] : '?',
                                  style: const TextStyle(
                                    color: AppColors.peopleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      target.person.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      target.reasons.first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _careScoreColor(
                                    target.score,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                ),
                                child: Text(
                                  '${target.score}점',
                                  style: TextStyle(
                                    color: _careScoreColor(target.score),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 180.ms),

            if (selectedRelationship == null &&
                searchQuery.isEmpty &&
                topCareTargets.isNotEmpty)
              const SizedBox(height: AppTheme.spacingM),

            // 사람 목록
            Expanded(
              child: people.isEmpty
                  ? _EmptyState(
                      searchQuery: searchQuery,
                      onAdd: () => _showAddPersonSheet(context),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingL,
                        0,
                        AppTheme.spacingL,
                        140,
                      ),
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final person = people[index];
                        return PersonCard(
                          person: person,
                          onTap: () => _showPersonDetail(context, person),
                        ).animate().fadeIn(
                          duration: 200.ms,
                          delay: Duration(milliseconds: 50 * (index % 10)),
                        );
                      },
                    ),
            ),
          ],
        ),
        // FAB
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL,
          child: FloatingActionButton(
            heroTag: 'people_fab',
            onPressed: () => _showAddPersonSheet(context),
            backgroundColor: AppColors.peopleColor,
            child: const Icon(Iconsax.user_add),
          ).animate().scale(delay: 400.ms, duration: 300.ms),
        ),
        Positioned(
          right: AppTheme.spacingL,
          bottom: AppTheme.spacingL + 72,
          child: FloatingActionButton.small(
            heroTag: 'people_import_fab',
            tooltip: '연락처 가져오기',
            onPressed: () => _importFromContacts(context, ref),
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            foregroundColor: AppColors.peopleColor,
            child: const Icon(Icons.contacts),
          ).animate().scale(delay: 350.ms, duration: 250.ms),
        ),
      ],
    );
  }

  Future<void> _importFromContacts(BuildContext context, WidgetRef ref) async {
    final mode = await _showImportModeSheet(context);
    if (!context.mounted || mode == null) return;

    switch (mode) {
      case _ContactImportMode.single:
        await _importSingleContact(context, ref);
        return;
      case _ContactImportMode.all:
        await _importAllContacts(context, ref);
        return;
    }
  }

  Future<_ContactImportMode?> _showImportModeSheet(BuildContext context) {
    return showModalBottomSheet<_ContactImportMode>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.user),
                title: const Text('연락처 1명 선택'),
                subtitle: const Text('원하는 연락처를 직접 선택해서 추가'),
                onTap: () {
                  Navigator.of(sheetContext).pop(_ContactImportMode.single);
                },
              ),
              ListTile(
                leading: const Icon(Icons.contacts),
                title: const Text('연락처 전체 가져오기'),
                subtitle: const Text('기기 연락처를 한 번에 추가 (중복 제외)'),
                onTap: () {
                  Navigator.of(sheetContext).pop(_ContactImportMode.all);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importSingleContact(BuildContext context, WidgetRef ref) async {
    final importService = ref.read(contactImportServiceProvider);
    final result = await importService.pickSingleContact();
    if (!context.mounted) return;

    switch (result.status) {
      case ContactImportStatus.success:
        final imported = result.contact;
        if (imported == null) return;
        await _saveImportedContacts(context, ref, [imported]);
        return;
      case ContactImportStatus.permissionDenied:
        _showSnackBar(context, '연락처 권한이 필요합니다. 권한을 허용해주세요.');
        return;
      case ContactImportStatus.unsupported:
        _showSnackBar(context, result.message ?? '이 플랫폼에서는 지원되지 않습니다.');
        return;
      case ContactImportStatus.failed:
        _showSnackBar(context, result.message ?? '연락처 가져오기에 실패했습니다.');
        return;
      case ContactImportStatus.cancelled:
        return;
    }
  }

  Future<void> _importAllContacts(BuildContext context, WidgetRef ref) async {
    final importService = ref.read(contactImportServiceProvider);

    _showLoadingDialog(context, '연락처를 불러오는 중...');
    final result = await importService.getAllContacts();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return;

    switch (result.status) {
      case ContactImportStatus.success:
        if (result.contacts.isEmpty) {
          _showSnackBar(context, '가져올 연락처가 없습니다.');
          return;
        }

        final selectedContacts = await _showBulkPreviewSheet(
          context,
          result.contacts,
        );
        if (!context.mounted || selectedContacts == null) return;
        if (selectedContacts.isEmpty) {
          _showSnackBar(context, '선택된 연락처가 없습니다.');
          return;
        }

        await _saveImportedContacts(
          context,
          ref,
          selectedContacts,
          isBulk: true,
        );
        return;
      case ContactImportStatus.permissionDenied:
        _showSnackBar(context, '연락처 권한이 필요합니다. 권한을 허용해주세요.');
        return;
      case ContactImportStatus.unsupported:
        _showSnackBar(context, result.message ?? '이 플랫폼에서는 지원되지 않습니다.');
        return;
      case ContactImportStatus.failed:
        _showSnackBar(context, result.message ?? '연락처 가져오기에 실패했습니다.');
        return;
      case ContactImportStatus.cancelled:
        return;
    }
  }

  Future<List<ImportedContact>?> _showBulkPreviewSheet(
    BuildContext context,
    List<ImportedContact> contacts,
  ) {
    final selectedIndexes = <int>{...List.generate(contacts.length, (i) => i)};

    return showModalBottomSheet<List<ImportedContact>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedCount = selectedIndexes.length;
            final isAllSelected = selectedCount == contacts.length;

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '연락처 미리보기',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '총 ${contacts.length}명 중 $selectedCount명 선택됨',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              if (isAllSelected) {
                                selectedIndexes.clear();
                              } else {
                                selectedIndexes
                                  ..clear()
                                  ..addAll(
                                    List.generate(contacts.length, (i) => i),
                                  );
                              }
                            });
                          },
                          icon: Icon(
                            isAllSelected ? Icons.deselect : Icons.select_all,
                          ),
                          label: Text(isAllSelected ? '전체 해제' : '전체 선택'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (itemContext, index) {
                        final contact = contacts[index];
                        final isSelected = selectedIndexes.contains(index);

                        return CheckboxListTile(
                          value: isSelected,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.peopleColor,
                          title: Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _buildContactSubtitle(contact),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == true) {
                                selectedIndexes.add(index);
                              } else {
                                selectedIndexes.remove(index);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: selectedCount == 0
                            ? null
                            : () {
                                final selected = selectedIndexes.toList()
                                  ..sort();
                                Navigator.of(sheetContext).pop(
                                  selected
                                      .map((index) => contacts[index])
                                      .toList(),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peopleColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('선택한 $selectedCount명 가져오기'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveImportedContacts(
    BuildContext context,
    WidgetRef ref,
    List<ImportedContact> importedContacts, {
    bool isBulk = false,
  }) async {
    if (importedContacts.isEmpty) {
      _showSnackBar(context, '가져올 연락처가 없습니다.');
      return;
    }

    final existingPeople = ref.read(smartPeopleProvider);
    final existingKeys = existingPeople
        .map(_buildPersonKey)
        .whereType<String>()
        .toSet();
    final currentBatchKeys = <String>{};
    final toSave = <Person>[];
    var skipped = 0;

    for (final imported in importedContacts) {
      final name = imported.name.trim();
      if (name.isEmpty) {
        skipped++;
        continue;
      }

      final person = Person(
        id: '',
        familyId: '',
        name: name,
        birthday: imported.birthday,
        phone: _optional(imported.phone),
        email: _optional(imported.email),
        company: _optional(imported.company),
        createdAt: DateTime.now(),
        createdBy: '',
      );

      final key = _buildPersonKey(person);
      if (key != null &&
          (existingKeys.contains(key) || currentBatchKeys.contains(key))) {
        skipped++;
        continue;
      }

      if (key != null) {
        currentBatchKeys.add(key);
      }
      toSave.add(person);
    }

    if (toSave.isEmpty) {
      _showSnackBar(context, '추가할 연락처가 없습니다. (중복 또는 빈 데이터)');
      return;
    }

    try {
      if (isBulk) {
        _showLoadingDialog(context, '연락처를 저장하는 중...');
      }

      await ref.read(peopleServiceProvider).addPeople(toSave);

      if (!context.mounted) return;
      if (isBulk) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final message = isBulk
          ? '${toSave.length}명을 가져왔습니다'
          : '${toSave.first.name}님을 연락처에서 가져왔습니다';
      final suffix = skipped > 0 ? ' (중복/제외 $skipped명)' : '';
      _showSnackBar(context, '$message$suffix', backgroundColor: AppColors.peopleColor);
    } catch (e) {
      if (!context.mounted) return;
      if (isBulk) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnackBar(
        context,
        '연락처 저장 실패: $e',
        backgroundColor: AppColors.errorLight,
      );
    }
  }

  String? _buildPersonKey(Person person) {
    final phone = _normalizePhone(person.phone);
    if (phone != null) return 'p:$phone';

    final email = person.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) return 'e:$email';

    final name = person.name.trim().toLowerCase();
    if (name.isEmpty) return null;
    final company = person.company?.trim().toLowerCase() ?? '';
    return 'n:$name|c:$company';
  }

  String? _normalizePhone(String? phone) {
    if (phone == null) return null;
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  String _buildContactSubtitle(ImportedContact contact) {
    final lines = <String>[];
    if (contact.phone != null && contact.phone!.trim().isNotEmpty) {
      lines.add(contact.phone!.trim());
    }
    if (contact.email != null && contact.email!.trim().isNotEmpty) {
      lines.add(contact.email!.trim());
    }
    if (contact.company != null && contact.company!.trim().isNotEmpty) {
      lines.add(contact.company!.trim());
    }
    if (lines.isEmpty) return '연락처 정보 없음';
    return lines.join('  •  ');
  }

  String? _optional(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Color _careScoreColor(int score) {
    if (score >= 80) return AppColors.careScoreHigh;
    if (score >= 60) return AppColors.careScoreMedium;
    if (score >= 40) return AppColors.careScoreNormal;
    return AppColors.careScoreLow;
  }

  void _showAddPersonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddPersonSheet(),
    );
  }

  void _showPersonDetail(BuildContext context, Person person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PersonDetailSheet(person: person),
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RelationshipChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.peopleColor : AppColors.peopleColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.peopleColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onAdd;

  const _EmptyState({required this.searchQuery, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchQuery.isNotEmpty ? Iconsax.search_status : Iconsax.people,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              searchQuery.isNotEmpty ? '검색 결과가 없습니다' : '등록된 사람이 없습니다',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              searchQuery.isNotEmpty ? '다른 검색어로 시도해보세요' : '주변 사람들의 정보를 기록해보세요',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Iconsax.user_add),
                label: const Text('사람 추가하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peopleColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
