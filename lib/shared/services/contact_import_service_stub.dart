import 'contact_import_service.dart';

class UnsupportedContactImportService implements ContactImportService {
  @override
  Future<ContactImportResult> pickSingleContact() async {
    return const ContactImportResult.unsupported(
      '이 플랫폼에서는 연락처 가져오기를 지원하지 않습니다.',
    );
  }

  @override
  Future<ContactImportManyResult> getAllContacts() async {
    return const ContactImportManyResult.unsupported(
      '이 플랫폼에서는 연락처 가져오기를 지원하지 않습니다.',
    );
  }
}

ContactImportService createContactImportService() =>
    UnsupportedContactImportService();
