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
    try {
      await _storage.removeContact(account);
      setState(() {
        contacts.removeWhere((contact) => contact.actorId == account.actorId);
      });
    } catch (err) {
      logger.e('Failed to remove contact: $err');
    }
  }

  Widget _emptyWidget(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Center(
      child: Text('You don\'t have any contacts', style: th.bodyLarge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        automaticallyImplyLeading: widget.onPick == null,
      ),
      body: contacts.isEmpty
          ? _emptyWidget(context)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ContactCell(
                contact: contacts[i],
                onRemove: _removeContact,
                onPick: widget.onPick,
              ),
            ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.onPick});

  final Function(ExternalAccount account)? onPick;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({
    required this.contact,
    required this.onRemove,
    this.onPick,
  });
  final ExternalAccount contact;

  final Function(ExternalAccount)? onPick;
  final Function(ExternalAccount) onRemove;

  _onTap() {
    if (onPick != null) {
      onPick!(contact);
    } else {
      // TODO: OPEN CONTACT PAGE
    }
  }

  Widget _deleteButtonWidget() {
    if (onPick == null) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: IconButton(
          iconSize: 24,
          icon: const Icon(Icons.delete_outline),
          style: IconButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async => onRemove(contact),
        ),
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _onTap,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.person_3, size: 24),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, style: theme.textTheme.titleLarge),
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
              _deleteButtonWidget(),
            ],
          ),
          Divider(),
        ],
      ),
    );
  }
}
