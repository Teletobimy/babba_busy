import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_import_service.dart';

class MobileContactImportService implements ContactImportService {
  @override
  Future<ContactImportResult> pickSingleContact() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        return const ContactImportResult.permissionDenied();
      }

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) {
        return const ContactImportResult.cancelled();
      }

      final name = _resolveName(contact);
      if (name.isEmpty) {
        return const ContactImportResult.failed('이름이 없는 연락처는 가져올 수 없습니다.');
      }

      final phone = _firstNonEmpty(
        contact.phones.map((item) => item.number).toList(),
      );
      final email = _firstNonEmpty(
        contact.emails.map((item) => item.address).toList(),
      );
      final company = _firstNonEmpty(
        contact.organizations.map((item) => item.company).toList(),
      );
      final birthday = _resolveBirthday(contact.events);

      return ContactImportResult.success(
        ImportedContact(
          name: name,
          phone: phone,
          email: email,
          company: company,
          birthday: birthday,
        ),
      );
    } catch (e) {
      return ContactImportResult.failed('연락처를 불러오지 못했습니다: $e');
    }
  }

  @override
  Future<ContactImportManyResult> getAllContacts() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        return const ContactImportManyResult.permissionDenied();
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final imported = <ImportedContact>[];
      final dedupeKeys = <String>{};

      for (final contact in contacts) {
        final name = _resolveName(contact);
        if (name.isEmpty) continue;

        final phone = _firstNonEmpty(
          contact.phones.map((item) => item.number).toList(),
        );
        final email = _firstNonEmpty(
          contact.emails.map((item) => item.address).toList(),
        );
        final company = _firstNonEmpty(
          contact.organizations.map((item) => item.company).toList(),
        );
        final birthday = _resolveBirthday(contact.events);

        final key = _buildImportedKey(
          name: name,
          phone: phone,
          email: email,
          company: company,
        );
        if (dedupeKeys.contains(key)) continue;
        dedupeKeys.add(key);

        imported.add(
          ImportedContact(
            name: name,
            phone: phone,
            email: email,
            company: company,
            birthday: birthday,
          ),
        );
      }

      return ContactImportManyResult.success(imported);
    } catch (e) {
      return ContactImportManyResult.failed('연락처 목록을 불러오지 못했습니다: $e');
    }
  }

  String _resolveName(Contact contact) {
    final displayName = contact.displayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final first = contact.name.first.trim();
    final last = contact.name.last.trim();
    final fullName = '$last$first'.trim();
    return fullName;
  }

  String? _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  DateTime? _resolveBirthday(List<Event> events) {
    final now = DateTime.now();
    for (final event in events) {
      if (event.label != EventLabel.birthday) continue;
      try {
        final year = event.year ?? now.year;
        return DateTime(year, event.month, event.day);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _buildImportedKey({
    required String name,
    String? phone,
    String? email,
    String? company,
  }) {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone != null) return 'p:$normalizedPhone';

    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return 'e:$normalizedEmail';
    }

    final normalizedName = name.trim().toLowerCase();
    final normalizedCompany = company?.trim().toLowerCase() ?? '';
    return 'n:$normalizedName|c:$normalizedCompany';
  }

  String? _normalizePhone(String? phone) {
    if (phone == null) return null;
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) return null;
    return normalized;
  }
}

ContactImportService createContactImportService() =>
    MobileContactImportService();
