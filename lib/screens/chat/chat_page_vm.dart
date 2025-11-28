
import 'package:collection/collection.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:uuid/v4.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/chat/chat_manager.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/storage/account_storage.dart';

class ChatPageViewModel {
  final SyncModel syncModel;

  ChatPageViewModel(this.syncModel);

  Future<void> sendMessage(String message) async {
    if (syncModel.isLocal) {
      return;
    }

    final id = UuidV4().generate();

    final textMessage = TextMessage(
      id: id,
      authorId: currentUserId,
      createdAt: DateTime.now().toUtc(),
      text: message,
    );

    try {
      await chatManager.addMessage(textMessage);
      await syncModel.sendChatFrame(textMessage);
    } catch (err, st) {
      logger.error('Failed to send message', err, st);

      chatManager.addMessage(
        TextMessage(
          id: id,
          authorId: currentUserId,
          text: message,
          status: MessageStatus.error,
        ),
      );
    }
  }

  ChatManager get chatManager => syncModel.chatManager;
  String get currentUserId => AccountSecureStorage.instance.account.actorId;

  Future<User> resolveUser(String actorId) async {
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
