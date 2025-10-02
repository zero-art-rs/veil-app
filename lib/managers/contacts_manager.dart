import 'dart:async';

import 'package:rxdart/subjects.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sharing/spk_manager.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';

class Contact {
  final ExternalAccount account;
  final List<List<int>> spks;

  Contact({required this.account, required this.spks});
}

class ContactsManager {
  static final instance = ContactsManager();

  final BehaviorSubject<List<Contact>> _subject = BehaviorSubject.seeded([]);
  late Stream<List<Contact>> stream = _subject.stream;

  List<Contact> get current => _subject.value;

  Future<void> setup() async {
    final contacts = await _getContacts();

    current.addAll(contacts);
    _subject.add(current);
  }

  Future<void> addContact(SpkShareData spkShare) async {
    final insertedContact = await DB.instance.insertContact(spkShare);
    final contact = await DB.instance.getContact(
      insertedContact.account.actorId,
    );

    final index = current.indexWhere(
      (e) => e.account.actorId == contact.account.actorId,
    );

    if (index == -1) {
      current.add(contact);
    } else {
      current[index] = contact;
    }
  }

  Future<void> removeContact(String id) async {
    await DB.instance.deleteContact(actorId: id);

    current.removeWhere((element) => element.account.actorId == id);
    _subject.add(current);
  }

  Future<List<Contact>> _getContacts() async {
    final contacts = await DB.instance.getContactList();
    return contacts;
  }

  Future<void> removeSpk(String contactId, List<int> publicKey) async {
    final spkRemoved = current
        .firstWhere((element) => element.account.actorId == contactId)
        .spks
        .remove(publicKey);

    logger.i('Removed spk from contact: $spkRemoved');

    _subject.add(current);
    await DB.instance.removeSpk(publicKey);
  }
}
