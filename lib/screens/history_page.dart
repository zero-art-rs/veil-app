import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/editor_page.dart';
import 'package:zk_notion_app/storage/models.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.items, required this.doc});
  final List<ChangeEvent> items;
  final Document doc;

  _onChangeTap(ChangeEvent change, BuildContext context) {
    final forkedAutomergeDoc = doc.automergeDoc.docAtChangeHash(
      changeHash: change.changeHashHex,
    );

    final forkedDoc = Document(
      id: doc.id,
      title: doc.title,
      automergeDoc: forkedAutomergeDoc,
      members: doc.members,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorPage(
          doc: forkedDoc,
          isHistoryAccessible: false,
          isMemberListAccessible: false,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            return _ChangeEventCard(
              event: e,
              onTap: () => _onChangeTap(e, context),
            );
          },
        ),
      ),
    );
  }
}

class _ChangeEventCard extends StatelessWidget {
  const _ChangeEventCard({required this.event, this.onTap});
  final ChangeEvent event;
  final Function()? onTap;

  Widget _initialChangeLabel(BuildContext context) {
    if (event.isInitial) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Initial change', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      );
    } else {
      return Container();
    }
  }

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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Change',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _initialChangeLabel(context),
                ],
              ),
              
              const SizedBox(height: 4),

              Text(
                event.changeHashHex,
                style: theme.textTheme.bodyMedium?.merge(mono),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              Wrap(
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.today,
                    label: _formatDateFromSeconds(event.date),
                  ),
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
  final String title;
  final String changeHashHex;
  final String actorIdHex;
  final int date;
  final bool isInitial;

  const ChangeEvent({
    required this.title,
    required this.changeHashHex,
    required this.actorIdHex,
    required this.date,
    this.isInitial = false,
  });
}

String _two(int v) => v.toString().padLeft(2, '0');

String _formatDateFromSeconds(int seconds, {bool utc = false}) {
  final dt = utc
      ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}';
}
