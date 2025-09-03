import 'package:zk_notion_app/storage/app_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class ContactStorage {
  final _storage = AppStorage.shared;

  static const String _contactsKey = 'contacts';
  static final ContactStorage shared = ContactStorage();

  /// Return true if contact already exists, false otherwise
  Future<bool> addContact({required ExternalAccount account}) async {
    final contacts = await _storage.getObjectArray(_contactsKey);

    if (contacts.where((e) => e['actorId'] == account.actorId).isNotEmpty) {
      return true;
    }

    if (contacts.isEmpty) {
      await _storage.setArray(_contactsKey, [account.toJson()]);
    } else {
      await _storage.appendToArray(_contactsKey, account.toJson());
    }

    return false;
  }

  Future<List<ExternalAccount>> getContacts() async {
    final rawContacts = await _storage.getObjectArray(_contactsKey);
    return rawContacts.map((e) => ExternalAccount.fromJson(e)).toList();
  }

  Future<void> removeContact(ExternalAccount account) async {
    await _storage.removeWhere(
      _contactsKey,
      (e) => account.actorId == e['actorId'],
    );
  }

  Future<void> updateContact(ExternalAccount account) async {
    await _storage.updateWhere(
      _contactsKey,
      (e) => account.actorId == e['actorId'],
      account.toJson(),
    );
  }
}
