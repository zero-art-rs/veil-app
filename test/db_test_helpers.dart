import 'dart:math';

import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/storage/sqlite/consts.dart';

void insertFamiliarDocumentMember(DB db, String docId) async {
  await db.transaction((db) async {
    final account = ExternalAccount.fromAccount(
      Account.withName(Random().nextDouble().toString()),
    );

    await db.insertDocumentMember(
      documentId: docId,
      member: DocumentMember(account: account, isOwner: false),
    );

    await db.insertAccount(account: account, kind: AccountKind.familiar);
  });
}

// Future<Document> insertNewDocument(DB db) async {
//   return await db.insertNewDocument(
//     title: Random().nextDouble().toString(),
//     owner: ExternalAccount(
//       actorId: Random().nextDouble().toString(),
//       name: Random().nextDouble().toString(),
//       rawPublicKey: [],
//     ),
//   );
// }

Future<List<ExternalAccount>> getContactList(DB db) async {
  return await db.getContactList();
}
