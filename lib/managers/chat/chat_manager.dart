import 'package:collection/collection.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:veil/managers/chat/hive_chat_controller.dart';

/// `ChatManager` responds for a proper message handling
class ChatManager {
  final HiveChatController controller;

  ChatManager({required this.controller});

  Future<void> addMessage(Message message) async {
    final cachedMessage = controller.messages.firstWhereOrNull(
      (e) => e.id == message.id,
    );

    if (cachedMessage != null) {
      return await controller.updateMessage(cachedMessage, message);
    } else {
      return await controller.insertMessage(message);
    }
  }

  Future<void> sendMessage(Message message) async {
    return await controller.insertMessage(message);
  }
}
