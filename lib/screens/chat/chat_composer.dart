import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';
import 'package:veil/main.dart';

class ChatComposer extends Composer {
  const ChatComposer({super.key});

  @override
  State<Composer> createState() {
    return _ChatComposerState();
  }
}

class _ChatComposerState extends State<Composer> {
  final _key = GlobalKey();
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late final ValueNotifier<bool> _hasTextNotifier;

  @override
  void initState() {
    super.initState();
    _textController = widget.textEditingController ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasTextNotifier = ValueNotifier(_textController.text.trim().isNotEmpty);
    _focusNode.onKeyEvent = _handleKeyEvent;
    _textController.addListener(_handleTextControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _handleSubmitted(_textController.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textEditingController != oldWidget.textEditingController) {
      _textController.removeListener(_handleTextControllerChange);
      _textController = widget.textEditingController ?? TextEditingController();
      _textController.addListener(_handleTextControllerChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _hasTextNotifier.dispose();
    _textController.removeListener(_handleTextControllerChange);
    // Only try to dispose text controller if it's not provided, let
    // user handle disposing it how they want.
    if (widget.textEditingController == null) {
      _textController.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = widget.handleSafeArea == true
        ? MediaQuery.of(context).padding.bottom
        : 0.0;
    final onAttachmentTap = context.read<OnAttachmentTapCallback?>();
    final theme = context.select(
      (ChatTheme t) => (
        bodyMedium: t.typography.bodyMedium,
        onSurface: t.colors.onSurface,
        primary: t.colors.primary,
        surfaceContainerHigh: t.colors.surfaceContainerHigh,
        surfaceContainerLow: t.colors.surfaceContainerLow,
      ),
    );

    final sigmaX = widget.sigmaX ?? 0;
    final sigmaY = widget.sigmaY ?? 0;
    final shouldUseBackdropFilter = sigmaX > 0 || sigmaY > 0;

    final content = Container(
      key: _key,
      color:
          widget.backgroundColor ??
          (shouldUseBackdropFilter
              ? theme.surfaceContainerLow.withValues(alpha: 0.8)
              : theme.surfaceContainerLow),
      child: Column(
        children: [
          if (widget.topWidget != null) widget.topWidget!,
          Padding(
            padding: widget.handleSafeArea == true
                ? (widget.padding?.add(
                        EdgeInsets.only(bottom: bottomSafeArea),
                      ) ??
                      EdgeInsets.only(bottom: bottomSafeArea))
                : (widget.padding ?? EdgeInsets.zero),
            child: Row(
              children: [
                widget.attachmentIcon != null && onAttachmentTap != null
                    ? IconButton(
                        icon: widget.attachmentIcon!,
                        color:
                            widget.attachmentIconColor ??
                            theme.onSurface.withValues(alpha: 0.5),
                        onPressed: onAttachmentTap,
                      )
                    : const SizedBox.shrink(),
                SizedBox(width: widget.gap),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    contentInsertionConfiguration:
                        widget.contentInsertionConfiguration,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: theme.bodyMedium.copyWith(
                        color:
                            widget.hintColor ??
                            theme.onSurface.withValues(alpha: 0.5),
                      ),
                      border: widget.inputBorder,
                      filled: widget.filled,
                      fillColor:
                          widget.inputFillColor ??
                          theme.surfaceContainerHigh.withValues(alpha: 0.8),
                      hoverColor: Colors.transparent,
                    ),
                    style: theme.bodyMedium.copyWith(
                      color: widget.textColor ?? theme.onSurface,
                    ),
                    onSubmitted: _handleSubmitted,
                    onChanged: (value) {
                      _hasTextNotifier.value = value.trim().isNotEmpty;
                    },
                    textInputAction: widget.textInputAction,
                    keyboardAppearance: widget.keyboardAppearance,
                    autocorrect: widget.autocorrect ?? true,
                    autofocus: widget.autofocus,
                    textCapitalization: widget.textCapitalization,
                    keyboardType: widget.keyboardType,
                    focusNode: _focusNode,
                    maxLength: widget.maxLength,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                  ),
                ),
                SizedBox(width: widget.gap),
                if (widget.sendIcon != null && !widget.sendButtonHidden)
                  ValueListenableBuilder<bool>(
                    valueListenable: _hasTextNotifier,
                    builder: (context, hasText, child) {
                      if (widget.sendButtonVisibilityMode ==
                              SendButtonVisibilityMode.hidden &&
                          !hasText) {
                        return const SizedBox.shrink();
                      }

                      final isActive =
                          (hasText ||
                              widget.sendButtonVisibilityMode ==
                                  SendButtonVisibilityMode.always) &&
                          !widget.sendButtonDisabled;

                      return IconButton(
                        icon: widget.sendIcon!,
                        color: isActive
                            ? (widget.sendIconColor ??
                                  theme.onSurface.withValues(alpha: 0.5))
                            : (widget.emptyFieldSendIconColor ??
                                  widget.sendIconColor ??
                                  theme.onSurface.withValues(alpha: 0.5)),
                        onPressed:
                            (widget.sendButtonVisibilityMode ==
                                        SendButtonVisibilityMode.disabled &&
                                    !hasText) ||
                                widget.sendButtonDisabled
                            ? null
                            : () => _handleSubmitted(_textController.text),
                      );
                    },
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );

    return Positioned(
      left: widget.left,
      right: widget.right,
      top: widget.top,
      bottom: widget.bottom,
      child: ClipRect(
        child: shouldUseBackdropFilter
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
                child: content,
              )
            : content,
      ),
    );
  }

  void _measure() {
    if (!mounted) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;

      context.read<ComposerHeightNotifier>().setHeight(
        // only set real height of the composer, ignoring safe area
        widget.handleSafeArea == true ? height - bottomSafeArea : height,
      );
    }
  }

  void _handleTextControllerChange() {
    _hasTextNotifier.value = _textController.text.trim().isNotEmpty;
  }

  void _handleSubmitted(String text) {
    if (widget.allowEmptyMessage == false && text.trim().isEmpty) return;
    context.read<OnMessageSendCallback?>()?.call(text.trim());
    if (widget.inputClearMode == InputClearMode.always) {
      _textController.clear();
    }
  }
}
