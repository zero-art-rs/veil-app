import 'package:flutter/material.dart';

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
