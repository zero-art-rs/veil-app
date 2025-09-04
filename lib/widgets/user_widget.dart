import 'package:flutter/material.dart';

class UserInfo {
  final String name;
  final String actorId;
  final String publicKey;
  const UserInfo({
    required this.name,
    required this.actorId,
    required this.publicKey,
  });
}

/// A simple, non-modal view showing user info.
/// Use inside any page/body: `UserInfoView(info: ..., onAdd: ..., onCancel: ...)`
class UserInfoView extends StatelessWidget {
  const UserInfoView({
    super.key,
    required this.info,
    required this.onAdd,
    required this.onCancel,
  });

  final UserInfo info;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('User info', style: theme.textTheme.titleLarge),
                Divider(),
                const SizedBox(height: 12),

                _InfoRow(
                  label: 'Name',
                  child: Text(info.name, style: theme.textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),

                _InfoRow(
                  label: 'Actor ID',
                  child: _MonoBlock(text: info.actorId),
                ),
                const SizedBox(height: 10),

                _InfoRow(
                  label: 'Public key',
                  child: _MonoBlock(text: info.publicKey, maxHeight: 120),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text(
                          'Add to contacts',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label + value row
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Read-only mono block for IDs/keys (no selection/copy)
class _MonoBlock extends StatelessWidget {
  const _MonoBlock({required this.text, this.maxHeight});
  final String text;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        softWrap: true,
        overflow: TextOverflow.fade,
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono'),
      ),
    );

    if (maxHeight != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: box,
        ),
      );
    }
    return box;
  }
}
