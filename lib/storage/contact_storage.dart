import 'package:zk_notion_app/storage/app_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class ContactStorage {
  final _storage = AppStorage.shared;

  static const String contactsKey = 'contacts';
  static final ContactStorage shared = ContactStorage();

  Future<void> addContact({required ExternalAccount account}) async {
    final contacts = await _storage.getObjectArray(contactsKey);

    if (contacts.where((e) => e['actorId'] == account.actorId).isNotEmpty) return;

    if (contacts.isEmpty) {
      await _storage.setArray(contactsKey, [account.toJson()]);
    } else {
      await _storage.appendToArray(contactsKey, account.toJson());
    }
  }

  Future<List<ExternalAccount>> getContacts() async {
    final rawContacts = await _storage.getObjectArray(contactsKey);
    return rawContacts.map((e) => ExternalAccount.fromJson(e)).toList();
  }

  Future<void> removeContact(ExternalAccount account) async {
    await _storage.removeWhere(contactsKey, (e) => account.actorId == e['actorId']);
  }

  Future<void> updateContact(ExternalAccount account) async {
    await _storage.updateWhere(
      contactsKey,
      (e) => account.actorId == e['actorId'],
      account.toJson(),
    );
  }
}
