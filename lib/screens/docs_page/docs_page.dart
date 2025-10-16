import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/docs_page/docs_page_vm.dart';
import 'package:veil/screens/editor/editor_page.dart';
import 'package:veil/widgets/banner.dart';
import 'package:veil/widgets/ays_modal.dart';

enum _DocAction { delete }

class DocsPage extends StatelessWidget {
  const DocsPage({super.key});

  void _createDocumentModal(BuildContext context) {
    final controller = TextEditingController(text: '');
    final vm = context.read<DocsPageViewModel>();

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Create a document'),
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
                await vm.createDoc(controller.text);
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (err) {
                logger.e('Failed to create document: $err');
                TopBanner.show(
                  context: context,
                  message: 'Failed to create document',
                );
              }
            },
            child: Text('Create'),
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
        onPressed: () => _createDocumentModal(context),
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
                onDelete: () => aysAsyncModal(
                  context: context,
                  title: 'Delete document',
                  content:
                      'Are you sure to delete ${vm.syncModels[i].groupContext.retrieveGroupInfo().name}?',
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
  const _DocCard({required this.doc, this.onDelete});
  final SyncModel doc;
  final VoidCallback? onDelete;

  GroupInfo get groupInfo => doc.groupContext.retrieveGroupInfo();

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
                              case _DocAction.delete:
                                onDelete?.call();
                            }
                          },
                          itemBuilder: (context) => [
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
                      groupInfo.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.groupContext.getOwner().name,
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
