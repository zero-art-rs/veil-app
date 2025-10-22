import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/v4.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';

class ChatPageViewModel extends ChangeNotifier {
  final SyncModel syncModel;

  ChatPageViewModel(this.syncModel);

  Future<void> sendMessage(String message) async {
    if (syncModel.isLocal) {
      return;
    }

    final textMessage = TextMessage(
      id: UuidV4().generate(),
      authorId: currentUserId,
      createdAt: DateTime.now().toUtc(),
      text: message,
    );

    await chatManager.addMessage(textMessage);
    final json = jsonEncode(textMessage);

    await syncModel.sendChatFrame(utf8.encode(json));
  }

  ChatManager get chatManager => syncModel.chatManager;
  String get currentUserId => AccountSecureStorage.instance.account.actorId;

  User resolveUser(String actorId) {
    final user = syncModel.groupContext
        .retrieveGroupInfo()
        .members
        .firstWhereOrNull((e) => e.id == actorId);

    if (user == null) {
      return User(id: actorId, name: 'Unknown');
    }

    return User(id: user.id, name: user.name);
  }
}
