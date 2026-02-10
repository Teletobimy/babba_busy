import 'package:babba/shared/utils/chat_attachment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatAttachmentPolicy', () {
    test('allows supported extensions', () {
      expect(ChatAttachmentPolicy.isAllowed('photo.jpg'), isTrue);
      expect(ChatAttachmentPolicy.isAllowed('report.PDF'), isTrue);
      expect(ChatAttachmentPolicy.isAllowed('slides.pptx'), isTrue);
      expect(ChatAttachmentPolicy.isAllowed('archive.zip'), isTrue);
    });

    test('blocks dangerous extensions', () {
      expect(ChatAttachmentPolicy.isBlocked('run.exe'), isTrue);
      expect(ChatAttachmentPolicy.isBlocked('script.ps1'), isTrue);
      expect(ChatAttachmentPolicy.isAllowed('run.exe'), isFalse);
    });

    test('enforces size limit', () {
      expect(ChatAttachmentPolicy.isWithinSizeLimit(1024), isTrue);
      expect(
        ChatAttachmentPolicy.isWithinSizeLimit(
          ChatAttachmentPolicy.maxAttachmentBytes + 1,
        ),
        isFalse,
      );
    });
  });
}
