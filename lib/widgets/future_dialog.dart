import 'dart:convert';
import 'package:flutter/material.dart';

class FutureDialogError implements Exception {
  final String title;
  final String content;

  FutureDialogError(this.title, this.content);

  @override
  String toString() => content;
}

Future<void> showFutureDialog<T>({
  required BuildContext context,
  required Future<T> Function() work,
  String title = "Confirmation",
  String message = "Do you want to continue?",
  String applyText = "Apply",
  String cancelText = "Cancel",
  String successTitle = "Success",
  String okText = "OK",
  String errorTitle = "Error",
  String errorOkText = "OK",
  Widget Function(T result)? successBuilder,
  Widget Function(FutureDialogError error)? errorBuilder,
  Widget? preview,
  bool autoStart = false,
  Size dialogSize = const Size(320, 160),
  List<Widget> Function(BuildContext context, VoidCallback runWork)?
  initialButtons,
  List<Widget> Function(
    BuildContext context,
    T result,
    VoidCallback closeWithOk,
  )?
  successButtons,
  List<Widget> Function(BuildContext context, FutureDialogError error)?
  errorButtons,
  VoidCallback? onSuccessOk,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _FutureDialog<T>(
        work: work,
        title: title,
        message: message,
        applyText: applyText,
        cancelText: cancelText,
        successTitle: successTitle,
        okText: okText,
        errorTitle: errorTitle,
        errorOkText: errorOkText,
        successBuilder: successBuilder,
        errorBuilder: errorBuilder,
        preview: preview,
        autoStart: autoStart,
        dialogSize: dialogSize,
        initialButtons: initialButtons,
        successButtons: successButtons,
        errorButtons: errorButtons,
        onSuccessOk: onSuccessOk,
      );
    },
  );
}

class _FutureDialog<T> extends StatefulWidget {
  final Future<T> Function() work;
  final String title;
  final String message;
  final String applyText;
  final String cancelText;
  final String successTitle;
  final String okText;
  final String errorTitle;
  final String errorOkText;
  final Widget Function(T result)? successBuilder;
  final Widget Function(FutureDialogError error)? errorBuilder;
  final Widget? preview;
  final bool autoStart;
  final Size dialogSize;
  final List<Widget> Function(BuildContext context, VoidCallback runWork)?
  initialButtons;
  final List<Widget> Function(
    BuildContext context,
    T result,
    VoidCallback closeWithOk,
  )?
  successButtons;
  final List<Widget> Function(BuildContext context, FutureDialogError error)?
  errorButtons;
  final VoidCallback? onSuccessOk;

  const _FutureDialog({
    required this.work,
    required this.title,
    required this.message,
    required this.applyText,
    required this.cancelText,
    required this.successTitle,
    required this.okText,
    required this.errorTitle,
    required this.errorOkText,
    this.successBuilder,
    this.errorBuilder,
    this.preview,
    this.autoStart = false,
    required this.dialogSize,
    this.initialButtons,
    this.successButtons,
    this.errorButtons,
    this.onSuccessOk,
  });

  @override
  State<_FutureDialog<T>> createState() => _FutureDialogState<T>();
}

class _FutureDialogState<T> extends State<_FutureDialog<T>> {
  bool _isProcessing = false;
  T? _result;
  FutureDialogError? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _runWork();
    }
  }

  Future<void> _runWork() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.work();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = e is FutureDialogError
            ? e
            : FutureDialogError(widget.errorTitle, e.toString());
      });
    }
  }

  void _closeWithOk() {
    widget.onSuccessOk?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isInitial =
        !_isProcessing &&
        _result == null &&
        _error == null &&
        !widget.autoStart;
    final isSuccess = _result != null;
    final isError = _error != null;

    return AlertDialog(
      title: Text(
        isError
            ? _error!.title
            : isSuccess
            ? widget.successTitle
            : widget.title,
      ),
      content: SizedBox(
        width: widget.dialogSize.width,
        height: widget.dialogSize.height,
        child: Center(
          child: _isProcessing
              ? const CircularProgressIndicator()
              : isError
              ? (widget.errorBuilder?.call(_error!) ??
                    _DefaultErrorWidget(error: _error!))
              : isSuccess
              ? (widget.successBuilder != null
                    ? widget.successBuilder!(_result as T)
                    : const SizedBox.shrink())
              : widget.preview ?? Text(widget.message),
        ),
      ),
      actions: [
        if (isInitial)
          Row(
            spacing: 12,
            children:
                widget.initialButtons?.call(context, _runWork) ??
                [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.cancelText),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _runWork,
                      child: Text(widget.applyText),
                    ),
                  ),
                ],
          ),
        if (isSuccess)
          Row(
            spacing: 12,
            children:
                widget.successButtons?.call(
                  context,
                  _result as T,
                  _closeWithOk,
                ) ??
                [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closeWithOk,
                      child: Text(widget.okText),
                    ),
                  ),
                ],
          ),
        if (isError)
          Row(
            spacing: 12,
            children:
                widget.errorButtons?.call(context, _error!) ??
                [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.errorOkText),
                    ),
                  ),
                ],
          ),
      ],
    );
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final FutureDialogError error;

  const _DefaultErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Text(error.content, style: Theme.of(context).textTheme.bodyMedium);
  }
}
