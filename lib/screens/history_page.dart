import 'package:flutter/material.dart';
import 'package:zk_notion_app/src/rust/api/automerge.dart';

/// UI-only demo screen that shows a list of change events.
/// Each cell displays:
/// - change hash (title + hex)
/// - date
/// - actor_id (hex)
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.items});
  final List<ChangeEvent> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    print(items);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Change Events'), centerTitle: true),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final e = items[index];
            return _ChangeEventCard(event: e);
          },
        ),
      ),
    );
  }
}

class _ChangeEventCard extends StatelessWidget {
  const _ChangeEventCard({required this.event});
  final ChangeEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = const TextStyle(fontFamily: 'RobotoMono');

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1.5,
      shadowColor: Colors.black,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {}, // UI only; hook up navigation or details if needed
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title (change name)
                        Text(
                          'Change',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Hex (change hash)
                        Text(
                          event.changeHashHex,
                          style: theme.textTheme.bodyMedium?.merge(mono),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.today, label: _formatDate(event.date)),
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: event.actorIdHex,
                    monospace: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.monospace = false,
  });
  final IconData icon;
  final String label;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            // 👈 this allows the text to shrink and ellipsize
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (monospace
                          ? const TextStyle(fontFamily: 'RobotoMono')
                          : const TextStyle())
                      .merge(Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeEvent {
  final String title; // e.g., "Profile updated"
  final String changeHashHex; // e.g., 0xABCDEF...
  final String actorIdHex; // e.g., 0x1234...
  final int date;

  const ChangeEvent({
    required this.title,
    required this.changeHashHex,
    required this.actorIdHex,
    required this.date,
  });
}

String _two(int v) => v.toString().padLeft(2, '0');
String _formatDate(int timestamp) {
  final d = DateTime.fromMicrosecondsSinceEpoch(timestamp);
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}
