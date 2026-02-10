/// 채팅 첨부 파일 정책 (허용 확장자/용량 제한)
class ChatAttachmentPolicy {
  static const int maxAttachmentBytes = 20 * 1024 * 1024; // 20MB

  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
  };

  static const Set<String> documentExtensions = {
    'pdf',
    'txt',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  };

  static const Set<String> archiveExtensions = {'zip'};

  static const Set<String> blockedExtensions = {
    'exe',
    'msi',
    'apk',
    'dmg',
    'bat',
    'cmd',
    'sh',
    'js',
    'jar',
    'com',
    'scr',
    'ps1',
  };

  static Set<String> get allowedExtensions => {
    ...imageExtensions,
    ...documentExtensions,
    ...archiveExtensions,
  };

  static String extractExtension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  static bool isImage(String fileName) {
    return imageExtensions.contains(extractExtension(fileName));
  }

  static bool isBlocked(String fileName) {
    return blockedExtensions.contains(extractExtension(fileName));
  }

  static bool isAllowed(String fileName) {
    final extension = extractExtension(fileName);
    return extension.isNotEmpty && allowedExtensions.contains(extension);
  }

  static bool isWithinSizeLimit(int bytes) => bytes <= maxAttachmentBytes;

  static String mimeTypeForFile(String fileName) {
    final extension = extractExtension(fileName);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
