import 'dart:async';

import 'package:flutter/material.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/contacts_manager.dart';

class _ContactsScreenState extends State<ContactsScreen> {
  final _contactsManager = ContactsManager.instance;

  List<Contact> contacts = [];
  StreamSubscription<List<Contact>>? _subscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
  }

  void _init() async {
    _subscription = _contactsManager.stream.listen((event) {
      setState(() {
        contacts = event;
      });
    });
  }

  Future<void> _removeContact(String id) async {
    try {
      await _contactsManager.removeContact(id);
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
                onRemove: (e) => _removeContact(e.account.actorId),
                onPick: widget.onPick,
              ),
            ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.onPick});

  final Function(Contact account)? onPick;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({
    required this.contact,
    required this.onRemove,
    this.onPick,
  });
  final Contact contact;

  final Function(Contact)? onPick;
  final Function(Contact) onRemove;

  _onTap() {
    if (onPick != null) {
      onPick!(contact);
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
                    Text(
                      contact.account.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contact.account.actorId,
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
              Text(
                'Spks: ${contact.spks.length}',
                style: theme.textTheme.bodySmall,
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
