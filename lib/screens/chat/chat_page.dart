import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/chat/chat_page_vm.dart';
import 'package:veil/utils/platform.dart';

class ChatPage extends StatelessWidget {
  final SyncModel syncModel;
  final Function? onBackPressed;

  const ChatPage({super.key, required this.syncModel, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatPageViewModel>(
      create: (_) => ChatPageViewModel(syncModel),
      child: _ChatView(key: key, onBackPressed: onBackPressed),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({super.key, this.onBackPressed});

  final Function? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatPageViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: PlatformUtils.isDesktop
            ? CloseButton(onPressed: () => onBackPressed?.call())
            : BackButton(),
      ),
      body: Chat(
        chatController: vm.chatManager.controller,
        currentUserId: vm.currentUserId,
        onMessageSend: (text) async {
          vm.sendMessage(text);
        },
        resolveUser: (UserID id) async {
          return vm.resolveUser(id);
        },
      ),
    );
  }
}
