import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/sync_provider.dart';
import 'package:zk_notion_app/screens/docs_page/docs_page_vm.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/screens/editor/editor_page.dart';
import 'package:zk_notion_app/widgets/banner.dart';
import 'package:zk_notion_app/widgets/ays_modal.dart';

enum _DocAction { edit, delete, share }

class DocsPage extends StatelessWidget {
  const DocsPage({super.key});

  void _cuDocumentModal(
    BuildContext context, {
    Document? document,
    bool isCreateFlow = true,
  }) {
    final controller = TextEditingController(text: document?.title ?? '');
    final vm = context.read<DocsPageViewModel>();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          isCreateFlow ? 'Create a document' : 'Update document name',
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            label: Text('Input document title'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                if (isCreateFlow) {
                  await vm.createDoc(controller.text);
                } else {
                  await vm.updateDocumentName(
                    document!,
                    title: controller.text,
                  );
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (err) {
                logger.e(
                  'Failed to ${isCreateFlow ? "create" : "update"} document: $err',
                );
                TopBanner.show(
                  context: context,
                  message:
                      'Failed to ${isCreateFlow ? "create" : "update"} document',
                );
              }
            },
            child: Text(isCreateFlow ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DocsPageViewModel>();
    final th = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          spacing: 8,
          children: [
            const Icon(Icons.description_outlined),
            Text('Docs', style: th.titleLarge),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _cuDocumentModal(context, isCreateFlow: true),
        label: const Icon(Icons.add),
      ),
      body: vm.syncModels.isEmpty
          ? const _NodocumentsYet()
          : GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: vm.syncModels.length,
              itemBuilder: (context, i) => _DocCard(
                doc: vm.syncModels[i],
                onDelete: () => aysModal(
                  context: context,
                  title: 'Delete document',
                  content:
                      'Are you sure to delete ${vm.syncModels[i].document.title}?',
                  callback: () async {
                    try {
                      await vm.deleteDoc(vm.syncModels[i].document);
                    } catch (err) {
                      if (!context.mounted) return;
                      TopBanner.show(
                        context: context,
                        message: 'Failed to delete document',
                      );
                      logger.e('Failed to delete document: $err');
                    }
                  },
                ),
                onEdit: () => _cuDocumentModal(
                  context,
                  document: vm.syncModels[i].document,
                  isCreateFlow: false,
                ),
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

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, this.onEdit, this.onDelete});
  final SyncProviderModel doc;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shadowColor: Colors.black,
      color: theme.colorScheme.surface.withAlpha(25),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditorPage(syncModel: doc)),
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
                                onEdit?.call();
                              case _DocAction.delete:
                                onDelete?.call();
                              case _DocAction.share:
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
                      doc.document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'test',
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
