import 'package:flutter/material.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/storage/contact_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class Contact {
  final String name;
  final String actorId;
  const Contact({required this.name, required this.actorId});
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _storage = ContactStorage();
  late List<ExternalAccount> contacts = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    try {
      final contacts = await _storage.getContacts();
      setState(() {
        this.contacts = contacts;
      });
    } catch (err) {
      logger.e('Failed to get contacts: $err');
    }
  }

  _removeContact(ExternalAccount account) async {
    await _storage.removeContact(account);
    setState(() {
      contacts.removeWhere((contact) => contact.actorId == account.actorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _ContactCell(contact: contacts[i], onRemove: _removeContact),
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.contact, required this.onRemove});
  final ExternalAccount contact;

  final Function(ExternalAccount) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  contact.actorId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              style: IconButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async => onRemove(contact),
            ),
          ),
        ],
      ),
    );
  }
}

// Example usage:
// ContactsScreen(
//   contacts: const [
//     Contact(name: 'Alice', actorId: 'f1a2b3c4-d5e6-7f89-0abc-def123456789'),
//     Contact(name: 'Bob', actorId: '123e4567-e89b-12d3-a456-426614174000'),
//   ],
// )
