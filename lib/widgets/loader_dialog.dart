import 'package:flutter/material.dart';

Future<T?> showLoaderDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext ctx, VoidCallback startWork)
  initialBuilder,
  required Future<T> Function() work,
  Widget Function(BuildContext ctx)? loaderBuilder,
  bool barrierDismissible = false,
}) async {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      return _LoaderDialog<T>(
        initialBuilder: initialBuilder,
        work: work,
        loaderBuilder: loaderBuilder,
      );
    },
  );
}

class _LoaderDialog<T> extends StatefulWidget {
  final Widget Function(BuildContext ctx, VoidCallback startWork)
  initialBuilder;
  final Future<T> Function() work;
  final Widget Function(BuildContext ctx)? loaderBuilder;

  const _LoaderDialog({
    required this.initialBuilder,
    required this.work,
    this.loaderBuilder,
  });

  @override
  State<_LoaderDialog<T>> createState() => _LoaderDialogState<T>();
}

class _LoaderDialogState<T> extends State<_LoaderDialog<T>> {
  bool _loading = false;

  void _startWork() async {
    setState(() => _loading = true);
    try {
      final result = await widget.work();
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _loading
            ? (widget.loaderBuilder?.call(context) ??
                  const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ))
            : widget.initialBuilder(context, _startWork),
      ),
    );
  }
}
