import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/chat/chat_page_vm.dart';
import 'package:veil/utils/platform.dart';

class ChatPage extends StatefulWidget {
  final SyncModel syncModel;
  final VoidCallback? onBackPressed;

  const ChatPage({super.key, required this.syncModel, this.onBackPressed});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatPageViewModel _viewModel = ChatPageViewModel(widget.syncModel);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: PlatformUtils.isDesktop
            ? CloseButton(onPressed: widget.onBackPressed)
            : const BackButton(),
      ),
      body: Chat(
        theme: ChatTheme.dark(),
        chatController: _viewModel.chatManager.controller,
        currentUserId: _viewModel.currentUserId,
        onMessageSend: (text) async => await _viewModel.sendMessage(text),
        resolveUser: (UserID id) async {
          return _viewModel.resolveUser(id);
        },
        builders: Builders(
          chatMessageBuilder:
              (
                context,
                message,
                index,
                animation,
                child, {
                bool? isRemoved,
                required bool isSentByMe,
                MessageGroupStatus? groupStatus,
              }) {
                final isSystemMessage = message.authorId == 'system';
                final isFirstInGroup = groupStatus?.isFirst ?? true;
                final isLastInGroup = groupStatus?.isLast ?? true;
                final shouldShowAvatar =
                    !isSystemMessage && isLastInGroup && isRemoved != true;
                final isCurrentUser =
                    message.authorId == _viewModel.currentUserId;
                final shouldShowUsername =
                    !isSystemMessage && isFirstInGroup && isRemoved != true;

                Widget? avatar;
                if (shouldShowAvatar) {
                  avatar = Padding(
                    padding: EdgeInsets.only(
                      left: isCurrentUser ? 8 : 0,
                      right: isCurrentUser ? 0 : 8,
                    ),
                    child: Avatar(userId: message.authorId),
                  );
                } else if (!isSystemMessage) {
                  avatar = const SizedBox(width: 40);
                }

                return ChatMessage(
                  message: message,
                  index: index,
                  animation: animation,
                  isRemoved: isRemoved,
                  groupStatus: groupStatus,
                  topWidget: shouldShowUsername
                      ? Padding(
                          padding: EdgeInsets.only(
                            bottom: 4,
                            left: isCurrentUser ? 0 : 48,
                            right: isCurrentUser ? 48 : 0,
                          ),
                          child: Username(userId: message.authorId),
                        )
                      : null,
                  leadingWidget: !isCurrentUser
                      ? avatar
                      : isSystemMessage
                      ? null
                      : const SizedBox(width: 40),
                  trailingWidget: isCurrentUser
                      ? avatar
                      : isSystemMessage
                      ? null
                      : const SizedBox(width: 40),
                  receivedMessageScaleAnimationAlignment:
                      (message is SystemMessage)
                      ? Alignment.center
                      : Alignment.centerLeft,
                  receivedMessageAlignment: (message is SystemMessage)
                      ? AlignmentDirectional.center
                      : AlignmentDirectional.centerStart,
                  horizontalPadding: (message is SystemMessage) ? 0 : 8,
                  child: child,
                );
              },
        ),
      ),
    );
  }
}
