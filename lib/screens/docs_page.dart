// import 'package:flutter/material.dart';
// import 'package:zk_notion_app/main.dart';
// import 'package:zk_notion_app/storage/account_storage.dart';
// import 'package:zk_notion_app/screens/editor/editor_page.dart';
// import 'package:zk_notion_app/storage/models.dart';
// import 'package:zk_notion_app/storage/sqlite/db.dart';
// import 'package:zk_notion_app/utils/banner.dart';
// import 'package:zk_notion_app/widgets/ays_modal.dart';

// class _StateDocsPage extends State<DocsPage> {
//   final _accStorage = AccountStorage();
//   List<Document> docs = [];
//   final _textFieldController = TextEditingController();

//   _createDoc(String title) async {
//     final resTitle = title.isEmpty ? 'Document' : title;

//     try {
//       final owner = await _accStorage.getAccount();

//       if (owner == null) {
//         throw 'To create a document, you must have account';
//       }

//       final doc = await DB.instance.transaction((db) async {
//         return await db.insertNewDocument(
//           title: resTitle,
//           owner: ExternalAccount.fromAccount(owner),
//         );
//       });

//       setState(() {
//         docs.add(doc);
//       });
//     } catch (err) {
//       logger.e('Failed to create document: $err');

//       if (!mounted) return;
//       TopBanner.show(context: context, message: 'Failed to create document');
//     }
//   }

//   _updateDoc(Document doc, {required String title}) async {
//     try {
//       await DB.instance.updateDocumentTitle(
//         Document(
//           id: doc.id,
//           title: title,
//           automergeDoc: doc.automergeDoc,
//           members: doc.members,
//           createdAt: doc.createdAt,
//           updatedAt: doc.updatedAt,
//         ),
//       );

//       setState(() {
//         docs.add(doc);
//       });
//     } catch (err) {
//       logger.e('Failed to update document: $err');
//       if (!mounted) return;
//       TopBanner.show(context: context, message: 'Failed to update document');
//     }
//   }

//   Future<void> _deleteDoc(Document doc) async {
//     aysModal(
//       context: context,
//       title: 'Delete document',
//       content: 'Are you sure to delete ${doc.title}?',
//       callback: () async {
//         try {
//           await DB.instance.deleteDocument(doc.id);
//           setState(() => docs.removeWhere((element) => element.id == doc.id));
//         } catch (err) {
//           logger.e('Failed to delete document: $err');
//           if (!mounted) return;
//           TopBanner.show(
//             context: context,
//             message: 'Failed to delete document',
//           );
//         }
//       },
//     );
//   }

//   void _cuDocumentModal(Document document, {bool isCreateFlow = true}) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: Text(
//           isCreateFlow ? 'Create a document' : 'Update document name',
//         ),
//         content: TextField(
//           controller: _textFieldController,
//           decoration: InputDecoration(label: Text('Input document title')),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, 'Cancel'),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               if (!isCreateFlow) {
//                 _updateDoc(document, title: _textFieldController.text);
//               } else {
//                 _createDoc(_textFieldController.text);
//               }

//               _textFieldController.clear();
//               Navigator.pop(context, isCreateFlow ? 'Create' : 'Update');
//             },
//             child: const Text('Create'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void initState() {
//     super.initState();

//     DB.instance.getDocumentList().then((value) {
//       setState(() => docs = value);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final th = Theme.of(context).textTheme;

//     return Scaffold(
//       appBar: AppBar(
//         titleSpacing: 12,
//         title: Row(
//           spacing: 8,
//           children: [
//             const Icon(Icons.description_outlined),
//             Text('Docs', style: th.titleLarge),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () => showDialog(
//           context: context,
//           builder: (BuildContext context) => AlertDialog(
//             title: Text('Create a document'),
//             content: TextField(
//               controller: _textFieldController,
//               decoration: InputDecoration(label: Text('Input document title')),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, 'Cancel'),
//                 child: const Text('Cancel'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   _cuDocumentModal(document)
//                   _textFieldController.clear();
//                   Navigator.pop(context, 'Create');
//                 },
//                 child: const Text('Create'),
//               ),
//             ],
//           ),
//         ),
//         label: const Icon(Icons.add),
//       ),
//       body: docs.isEmpty
//           ? _NodocumentsYet()
//           : GridView.builder(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
//               gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
//                 maxCrossAxisExtent: 280,
//                 mainAxisSpacing: 10,
//                 crossAxisSpacing: 10,
//                 childAspectRatio: 1,
//               ),
//               itemCount: docs.length,
//               itemBuilder: (context, i) => _DocCard(
//                 doc: docs[i],
//                 onDelete: () async => await _deleteDoc(docs[i]),
//                 onEdit: () async =>
//                     _cuDocumentModal(docs[i], isCreateFlow: false),
//               ),
//             ),
//     );
//   }
// }

// class DocsPage extends StatefulWidget {
//   const DocsPage({super.key});

//   @override
//   State<StatefulWidget> createState() {
//     return _StateDocsPage();
//   }
// }

// enum _DocAction { edit, delete, share }

// class _DocCard extends StatelessWidget {
//   const _DocCard({required this.doc, this.onEdit, this.onDelete});

//   final Document doc;
//   final VoidCallback? onEdit;
//   final VoidCallback? onDelete;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Material(
//       shadowColor: Colors.black,
//       color: theme.colorScheme.surface.withAlpha(25),
//       borderRadius: BorderRadius.circular(10),
//       clipBehavior: Clip.antiAlias,
//       elevation: 1.5,
//       child: InkWell(
//         onTap: () => Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => EditorPage(doc: doc)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             AspectRatio(
//               aspectRatio: 16 / 9,
//               child: Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       theme.colorScheme.secondaryContainer,
//                       theme.colorScheme.primaryContainer,
//                     ],
//                   ),
//                 ),
//                 child: Stack(
//                   children: [
//                     Positioned.fill(
//                       child: Padding(
//                         padding: const EdgeInsets.all(14),
//                         child: Opacity(
//                           opacity: 0.5,
//                           child: Icon(
//                             Icons.description,
//                             size: 64,
//                             color: theme.colorScheme.onPrimaryContainer,
//                           ),
//                         ),
//                       ),
//                     ),
//                     Positioned(
//                       top: 8,
//                       right: 8,
//                       child: Material(
//                         color: theme.colorScheme.surface,
//                         borderRadius: BorderRadius.circular(10),
//                         clipBehavior: Clip.antiAlias,
//                         child: PopupMenuButton<_DocAction>(
//                           tooltip: 'More options',
//                           onSelected: (value) {
//                             switch (value) {
//                               case _DocAction.edit:
//                                 onEdit?.call();
//                               case _DocAction.delete:
//                                 onDelete?.call();
//                               case _DocAction.share:
//                                 break;
//                             }
//                           },
//                           itemBuilder: (context) => [
//                             PopupMenuItem(
//                               value: _DocAction.delete,
//                               child: ListTile(
//                                 leading: const Icon(Icons.ios_share_outlined),
//                                 title: const Text('Share'),
//                                 contentPadding: EdgeInsets.zero,
//                                 dense: true,
//                               ),
//                             ),
//                             const PopupMenuDivider(),
//                             PopupMenuItem(
//                               value: _DocAction.edit,
//                               child: ListTile(
//                                 leading: const Icon(Icons.edit),
//                                 title: const Text('Edit'),
//                                 contentPadding: EdgeInsets.zero,
//                                 dense: true,
//                               ),
//                             ),
//                             const PopupMenuDivider(),
//                             PopupMenuItem(
//                               value: _DocAction.delete,
//                               child: ListTile(
//                                 leading: const Icon(Icons.delete_outline),
//                                 title: const Text('Delete'),
//                                 contentPadding: EdgeInsets.zero,
//                                 dense: true,
//                               ),
//                             ),
//                           ],
//                           icon: const Icon(Icons.more_vert),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       doc.title,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: theme.textTheme.titleSmall,
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       doc.ownerName(),
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: theme.textTheme.labelSmall,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _NodocumentsYet extends StatelessWidget {
//   const _NodocumentsYet();

//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Text(
//         "No documents currently",
//         style: TextStyle(
//           fontSize: 18,
//           fontWeight: FontWeight.w500,
//           color: Colors.grey,
//         ),
//       ),
//     );
//   }
// }
