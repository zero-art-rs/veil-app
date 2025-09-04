import 'package:flutter/material.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/screens/editor_page.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart';

class _StateDocsPage extends State<DocsPage> {
  final _docStorage = DocumentStorage();
  final _accStorage = AccountStorage();
  List<Document> docs = [];
  final _textFieldController = TextEditingController();

  createDoc(String title) async {
    final resTitle = title.isEmpty ? 'Document' : title;

    try {
      final owner = await _accStorage.getAccount();

      if (owner == null) {
        throw 'To create a document, you must have account';
      }

      final doc = await _docStorage.createDocument(
        title: resTitle,
        owner: DocumentMember(
          account: ExternalAccount.fromAccount(owner),
          isOwner: true,
        ),
      );

      setState(() {
        _textFieldController.clear();
        docs.add(doc);
      });
    } catch (err) {
      logger.e('Failed to create document: $err');
    }
  }

  deleteDoc(String id) {
    _docStorage
        .removeDocument(id)
        .then(
          (value) =>
              setState(() => docs.removeWhere((element) => element.id == id)),
        );
  }

  @override
  void initState() {
    super.initState();

    _docStorage.getDocuments().then((value) {
      setState(() => docs = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          spacing: 8,
          children: [
            const Icon(Icons.description_outlined),
            Text('Docs', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Create a document'),
            content: TextField(
              controller: _textFieldController,
              decoration: InputDecoration(label: Text('Input document title')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'Cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  createDoc(_textFieldController.text);
                  _textFieldController.clear();
                  Navigator.pop(context, 'Create');
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Create document'),
      ),
      body: docs.isEmpty
          ? _NodocumentsYet()
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: docs.length,
              itemBuilder: (context, i) =>
                  _DocCard(doc: docs[i], onDelete: () => deleteDoc(docs[i].id)),
            ),
    );
  }
}

class DocsPage extends StatefulWidget {
  const DocsPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _StateDocsPage();
  }
}

enum _DocAction { edit, delete }

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, this.onEdit, this.onDelete});

  final Document doc;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shadowColor: Colors.black,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditorPage(doc: doc)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Opacity(
                          opacity: 0.5,
                          child: Icon(
                            Icons.description,
                            size: 64,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: PopupMenuButton<_DocAction>(
                          tooltip: 'More options',
                          onSelected: (value) {
                            switch (value) {
                              case _DocAction.edit:
                                if (onEdit != null) return onEdit!();
                                Navigator.pushNamed(
                                  context,
                                  '/editor',
                                  arguments: {'doc': doc},
                                );
                                break;
                              case _DocAction.delete:
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Document was deleted'),
                                  ),
                                );
                                if (onDelete != null) return onDelete!();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Document was deleted'),
                                  ),
                                );
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _DocAction.delete,
                              child: ListTile(
                                leading: const Icon(Icons.ios_share_outlined),
                                title: const Text('Share'),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: _DocAction.edit,
                              child: ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: _DocAction.delete,
                              child: ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('Delete'),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.ownerName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodocumentsYet extends StatelessWidget {
  const _NodocumentsYet();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "No documents currently",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }
}
