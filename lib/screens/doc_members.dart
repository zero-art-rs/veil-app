import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/contacts_page.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class MemberScreenModel {
  final DocumentMember member;
  final bool isYou;

  MemberScreenModel({required this.member, this.isYou = false});
}

class DocumentMemberListScreen extends StatefulWidget {
  const DocumentMemberListScreen({
    super.key,
    required this.members,
    required this.doc,
  });

  final List<MemberScreenModel> members;

  final Document doc;

  @override
  State<DocumentMemberListScreen> createState() =>
      _DocumentMemberListScreenState();
}

class _DocumentMemberListScreenState extends State<DocumentMemberListScreen> {
  final _storage = DocumentStorage();

  void _onAddMember(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return ContactsScreen(
          onPick: (account) async => await _addMember(account),
        );
      },
    );
  }

  Future<void> _addMember(ExternalAccount member) async {
    setState(() {
      widget.members.add(
        MemberScreenModel(
          member: DocumentMember(account: member, isOwner: false),
        ),
      );
    });

    widget.doc.members.add(DocumentMember(account: member, isOwner: false));
    await _storage.addMember(widget.doc.id, widget.doc.members.last);
  }

  void _onRemoveMember(MemberScreenModel g) async {
    setState(() => widget.members.remove(g));

    widget.doc.members.removeWhere(
      (e) => e.account.actorId == g.member.account.actorId,
    );

    await _storage.removeMember(widget.doc.id, g.member.account.actorId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Document members')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.members.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Divider(height: 1, thickness: 1.2, color: dividerColor),
        ),
        itemBuilder: (context, i) {
          final g = widget.members[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    g.member.account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                g.member.account.actorId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            trailing: buildTrailing(theme, g),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddMember(context),
        tooltip: 'Add member',
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }

  Widget buildTrailing(ThemeData theme, MemberScreenModel g) {
    if (g.isYou) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'You',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return IconButton(
        tooltip: 'Remove member',
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => _onRemoveMember(g),
      );
    }
  }
}
