import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:zk_notion_app/extensions/safe_list.dart';
import 'package:zk_notion_app/utils/platform.dart';

class DifferencePage extends StatelessWidget {
  const DifferencePage({
    super.key,
    required this.oldDoc,
    required this.newDoc,
    required this.onClose,
  });

  final List<String> oldDoc;
  final List<String> newDoc;
  final void Function() onClose;

  @override
  Widget build(BuildContext context) {
    final maxLength = max(oldDoc.length, newDoc.length);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.onSurface,
      appBar: AppBar(
        leading: PlatformUtils.isDesktop
            ? CloseButton(onPressed: onClose)
            : BackButton(onPressed: onClose),
        title: Text('Difference'),
        backgroundColor: cs.onSurface,
        foregroundColor: cs.surface,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            for (var i = 0; i < maxLength; i++)
              PrettyDiffText(
                oldText: oldDoc.safeGet(i) ?? '',
                newText: newDoc.safeGet(i) ?? '',
              ),
          ],
        ),
      ),
    );
  }
}
