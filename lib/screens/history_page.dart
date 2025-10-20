import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/screens/difference_page.dart';

List<ChangeEvent> _prepareChangeList(SyncModel syncModel) {
  final members = syncModel.groupContext.retrieveGroupInfo().members;

  return syncModel.document.automergeDoc
      .getChangeList()
      .indexed
      .map(
        (e) => ChangeEvent(
          title: 'Change',
          actorIdHex: e.$2.actorIdHex(),
          changeHashHex: e.$2.changeHash(),
          date: e.$2.timestamp(),
          name:
              members
                  .firstWhereOrNull((elem) => elem.id == e.$2.actorIdHex())
                  ?.name ??
              e.$2.actorIdHex(),
          isInitial: e.$1 == 0,
        ),
      )
      .toList()
      .reversed
      .toList();
}

class HistoryPage extends StatelessWidget {
  HistoryPage({super.key, required this.syncModel, this.onChangeTap})
    : _items = _prepareChangeList(syncModel);

  final SyncModel syncModel;
  final List<ChangeEvent> _items;
  final void Function(BuildContext context, ChangeEvent change)? onChangeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Change Events'), centerTitle: true),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final change = _items[index];
            return _ChangeEventCard(
              event: change,
              onTap: () {
                if (onChangeTap != null) {
                  onChangeTap?.call(context, change);
                } else {
                  var (before, after) = syncModel.document.automergeDoc
                      .docsBeforeAfter(changeHash: change.changeHashHex);

                  final oldDoc = before.getBlocks();
                  final newDoc = after.getBlocks();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DifferencePage(
                        oldDoc: oldDoc,
                        newDoc: newDoc,
                        onClose: () => Navigator.pop(context),
                      ),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChangeEventCard extends StatelessWidget {
  _ChangeEventCard({required this.event, this.onTap});
  final ChangeEvent event;
  final Function()? onTap;

  final _materialColors = <MaterialColor>[
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.brown,
    Colors.blueGrey,
  ];

  Color colorFromId(String id) {
    final hash = id.hashCode;
    final index = hash.abs() % _materialColors.length;

    return _materialColors[index][800]!;
  }

  Widget _initialChangeLabel(BuildContext context) {
    if (event.isInitial) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Initial change',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
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
      color: theme.colorScheme.surface.withAlpha(80),
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

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.today,
                    label: _formatDateFromSeconds(event.date),
                  ),
                  // Expanded(
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: event.name,
                    monospace: true,
                    actorColor: colorFromId(event.actorIdHex),
                  ),
                  // ),
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
    this.actorColor,
  });
  final IconData icon;
  final String label;
  final bool monospace;
  final Color? actorColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: actorColor ?? theme.colorScheme.secondaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
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
  final String name;
  final int date;
  final bool isInitial;

  const ChangeEvent({
    required this.name,
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
