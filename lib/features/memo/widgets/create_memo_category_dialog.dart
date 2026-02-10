import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/memo_provider.dart';
import '../memo_category_utils.dart';

typedef CreatedMemoCategory = ({String id, String name, String color, String icon});

Future<CreatedMemoCategory?> showCreateMemoCategoryDialog({
  required BuildContext context,
  required WidgetRef ref,
  String title = '카테고리 추가',
  String confirmText = '추가',
}) async {
  final nameController = TextEditingController();
  var selectedColor = memoCategoryColorPresets.first;
  var selectedIcon = memoCategoryIconPresets.first;
  var isSubmitting = false;
  String? errorText;

  final result = await showDialog<CreatedMemoCategory>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> submit() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setState(() => errorText = '카테고리 이름을 입력해주세요');
              return;
            }

            setState(() {
              isSubmitting = true;
              errorText = null;
            });

            try {
              final categoryId = await ref.read(memoServiceProvider).addCategory(
                    name: name,
                    icon: selectedIcon,
                    color: selectedColor,
                  );
              if (categoryId == null) {
                throw Exception('카테고리 생성에 실패했습니다.');
              }

              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(
                (
                  id: categoryId,
                  name: name,
                  color: selectedColor,
                  icon: selectedIcon,
                ),
              );
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => errorText = '생성 실패: $e');
            } finally {
              if (dialogContext.mounted) {
                setState(() => isSubmitting = false);
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    maxLength: 20,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      hintText: '예: 업무, 회의, 공부',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('색상'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: memoCategoryColorPresets.map((colorHex) {
                      final color = parseMemoCategoryColor(colorHex);
                      final isSelected = selectedColor == colorHex;
                      return InkWell(
                        onTap: () => setState(() => selectedColor = colorHex),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black54
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('아이콘'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: memoCategoryIconPresets.map((iconName) {
                      final color = parseMemoCategoryColor(selectedColor);
                      return ChoiceChip(
                        label: Icon(
                          memoCategoryIconData(iconName),
                          size: 18,
                          color: selectedIcon == iconName ? Colors.white : color,
                        ),
                        selected: selectedIcon == iconName,
                        selectedColor: color,
                        onSelected: (_) {
                          setState(() => selectedIcon = iconName);
                        },
                      );
                    }).toList(),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(confirmText),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  return result;
}
