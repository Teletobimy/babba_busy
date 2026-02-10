import 'package:flutter_test/flutter_test.dart';
import 'package:babba/features/memo/memo_category_utils.dart';

void main() {
  group('deriveMemoTitle', () {
    test('uses explicit title when provided', () {
      final title = deriveMemoTitle(
        titleInput: '회의 메모',
        contentInput: '내용',
      );

      expect(title, '회의 메모');
    });

    test('uses first non-empty line from content when title is empty', () {
      final title = deriveMemoTitle(
        titleInput: '',
        contentInput: '\n  주간 회고 정리 \n세부 내용',
      );

      expect(title, '주간 회고 정리');
    });

    test('falls back to default when both title and content are empty', () {
      final title = deriveMemoTitle(
        titleInput: '',
        contentInput: '   ',
      );

      expect(title, '제목 없음');
    });
  });
}
