import 'package:flutter/material.dart';

Future<void> showFutureDialog({
  required BuildContext context,
  required Future<void> Function() work,
  String title = "Confirmation",
  String message = "Do you want to continue?",
  String applyText = "Apply",
  String cancelText = "Cancel",
  String successTitle = "Success",
  String successMessage = "Operation completed successfully.",
  String okText = "OK",
  String errorTitle = "Error",
  String errorMessage = "Something went wrong.",
  String errorOkText = "OK",
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _FutureDialog(
        work: work,
        title: title,
        message: message,
        applyText: applyText,
        cancelText: cancelText,
        successTitle: successTitle,
        successMessage: successMessage,
        okText: okText,
        errorTitle: errorTitle,
        errorMessage: errorMessage,
        errorOkText: errorOkText,
      );
    },
  );
}

class _FutureDialog extends StatefulWidget {
  final Future<void> Function() work;
  final String title;
  final String message;
  final String applyText;
  final String cancelText;
  final String successTitle;
  final String successMessage;
  final String okText;
  final String errorTitle;
  final String errorMessage;
  final String errorOkText;

  const _FutureDialog({
    required this.work,
    required this.title,
    required this.message,
    required this.applyText,
    required this.cancelText,
    required this.successTitle,
    required this.successMessage,
    required this.okText,
    required this.errorTitle,
    required this.errorMessage,
    required this.errorOkText,
  });

  @override
  State<_FutureDialog> createState() => _FutureDialogState();
}

class _FutureDialogState extends State<_FutureDialog> {
  bool _isProcessing = false;
  bool _isDone = false;
  bool _hasError = false;

  Future<void> _runWork() async {
    setState(() {
      _isProcessing = true;
      _hasError = false;
    });

    try {
      await widget.work();
      setState(() {
        _isProcessing = false;
        _isDone = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitial = !_isProcessing && !_isDone && !_hasError;

    return AlertDialog(
      title: Text(
        _hasError
            ? widget.errorTitle
            : _isDone
            ? widget.successTitle
            : widget.title,
      ),
      content: SizedBox(
        width: 320,
        height: 80,
        child: Center(
          child: _isProcessing
              ? const CircularProgressIndicator()
              : _hasError
              ? Text(widget.errorMessage)
              : _isDone
              ? Text(widget.successMessage)
              : Text(widget.message),
        ),
      ),
      actions: [
        Row(
          spacing: 16,
          children: [
            if (isInitial)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.cancelText),
                ),
              ),
            if (isInitial)
              Expanded(
                child: OutlinedButton(
                  onPressed: _runWork,
                  child: Text(widget.applyText),
                ),
              ),
            if (_isDone || _hasError)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_hasError ? widget.errorOkText : widget.okText),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
