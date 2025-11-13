import 'package:flutter/material.dart';
import 'package:veil/main.dart';

void aysModal({
  required BuildContext context,
  required String title,
  required String content,
  Function? callback,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: Text(content, style: Theme.of(context).textTheme.bodyLarge),
        actions: <Widget>[
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('No'),
                ),
              ),

              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await callback?.call();
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: Text('Yes'),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

Future<bool?> aysAsyncModal({
  required BuildContext context,
  required String title,
  required String content,
  Future<void> Function()? callback,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _AysModal(title: title, content: content, callback: callback);
    },
  );
}

class _AysModal extends StatefulWidget {
  final String title;
  final String content;
  final Future<void> Function()? callback;

  const _AysModal({required this.title, required this.content, this.callback});

  @override
  State<_AysModal> createState() => _AysModalState();
}

class _AysModalState extends State<_AysModal> {
  bool _loading = false;

  Future<void> _onYesPressed() async {
    if (widget.callback == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.callback!.call();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      logger.error('Failed to execute callback: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : Text(widget.content, style: Theme.of(context).textTheme.bodyLarge),
      actions: _loading
          ? null
          : <Widget>[
              Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _onYesPressed,
                      child: const Text('Yes'),
                    ),
                  ),
                ],
              ),
            ],
    );
  }
}
