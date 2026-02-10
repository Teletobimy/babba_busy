import 'contact_import_service_stub.dart'
    if (dart.library.io) 'contact_import_service_io.dart'
    as impl;

enum ContactImportStatus {
  success,
  cancelled,
  permissionDenied,
  unsupported,
  failed,
}

class ImportedContact {
  final String name;
  final String? phone;
  final String? email;
  final String? company;
  final DateTime? birthday;

  const ImportedContact({
    required this.name,
    this.phone,
    this.email,
    this.company,
    this.birthday,
  });
}

class ContactImportResult {
  final ContactImportStatus status;
  final ImportedContact? contact;
  final String? message;

  const ContactImportResult._({
    required this.status,
    this.contact,
    this.message,
  });

  const ContactImportResult.success(ImportedContact contact)
    : this._(status: ContactImportStatus.success, contact: contact);

  const ContactImportResult.cancelled()
    : this._(status: ContactImportStatus.cancelled);

  const ContactImportResult.permissionDenied()
    : this._(status: ContactImportStatus.permissionDenied);

  const ContactImportResult.unsupported([String? message])
    : this._(status: ContactImportStatus.unsupported, message: message);

  const ContactImportResult.failed(String message)
    : this._(status: ContactImportStatus.failed, message: message);
}

class ContactImportManyResult {
  final ContactImportStatus status;
  final List<ImportedContact> contacts;
  final String? message;

  const ContactImportManyResult._({
    required this.status,
    this.contacts = const [],
    this.message,
  });

  const ContactImportManyResult.success(List<ImportedContact> contacts)
    : this._(status: ContactImportStatus.success, contacts: contacts);

  const ContactImportManyResult.cancelled()
    : this._(status: ContactImportStatus.cancelled);

  const ContactImportManyResult.permissionDenied()
    : this._(status: ContactImportStatus.permissionDenied);

  const ContactImportManyResult.unsupported([String? message])
    : this._(status: ContactImportStatus.unsupported, message: message);

  const ContactImportManyResult.failed(String message)
    : this._(status: ContactImportStatus.failed, message: message);
}

abstract class ContactImportService {
  Future<ContactImportResult> pickSingleContact();
  Future<ContactImportManyResult> getAllContacts();
}

ContactImportService createContactImportService() =>
    impl.createContactImportService();
