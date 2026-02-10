import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../shared/models/memo_category.dart';

const List<String> memoCategoryColorPresets = <String>[
  '#64B5F6',
  '#FFB74D',
  '#4DB6AC',
  '#E57373',
  '#9575CD',
  '#4FC3F7',
  '#AED581',
  '#A1887F',
];

const List<String> memoCategoryIconPresets = <String>[
  'note_1',
  'book_1',
  'lamp_charge',
  'task_square',
];

Color parseMemoCategoryColor(String? colorHex) {
  if (colorHex == null || colorHex.isEmpty) {
    return const Color(0xFF64B5F6);
  }

  try {
    return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF64B5F6);
  }
}

IconData memoCategoryIconData(String? iconName) {
  switch (iconName) {
    case 'book_1':
      return Iconsax.book_1;
    case 'lamp_charge':
      return Iconsax.lamp_charge;
    case 'task_square':
      return Iconsax.task_square;
    case 'note_1':
    default:
      return Iconsax.note_1;
  }
}

MemoCategory? findMemoCategoryById(
  List<MemoCategory> categories,
  String? categoryId,
) {
  if (categoryId == null || categoryId.isEmpty) {
    return null;
  }

  for (final category in categories) {
    if (category.id == categoryId) {
      return category;
    }
  }
  return null;
}

MemoCategory? findMemoCategoryByName(
  List<MemoCategory> categories,
  String? categoryName,
) {
  if (categoryName == null || categoryName.trim().isEmpty) {
    return null;
  }

  final normalized = categoryName.trim().toLowerCase();
  for (final category in categories) {
    if (category.name.trim().toLowerCase() == normalized) {
      return category;
    }
  }
  return null;
}

String deriveMemoTitle({
  required String titleInput,
  required String contentInput,
}) {
  final normalizedTitle = titleInput.trim();
  if (normalizedTitle.isNotEmpty) {
    return normalizedTitle;
  }

  final fallback = _titleFromContent(contentInput.trim());
  if (fallback.isNotEmpty) {
    return fallback;
  }

  return '제목 없음';
}

String _titleFromContent(String content) {
  if (content.isEmpty) return '';

  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);

  if (lines.isEmpty) return '';

  final firstLine = lines.first;
  if (firstLine.length <= 30) {
    return firstLine;
  }

  return '${firstLine.substring(0, 30)}...';
}
