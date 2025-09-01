import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;

class Member {
  final String id;
  final String name;
  final bool isYou;
  Member({required this.id, required this.name, this.isYou = false});
}

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final List<Member> _members = [
    Member(id: 'grp_01A2B3', name: 'Collectors Club'),
    Member(id: 'grp_04C5D6', name: 'Vintage Fans', isYou: true),
    Member(id: 'grp_07E8F9', name: 'Daily Swappers'),
  ];

  void _onAddMember() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Add member action')));
  }

  void _onRemoveMember(Member g) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Remove member from "${g.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Document members')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _members.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Divider(height: 1, thickness: 1.2, color: dividerColor),
        ),
        itemBuilder: (context, i) {
          final g = _members[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                g.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            trailing: buildTrailing(theme, g),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddMember,
        tooltip: 'Add member',
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
    );
  }

  Widget buildTrailing(ThemeData theme, Member g) {
    if (g.isYou) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'You',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return IconButton(
        tooltip: 'Remove member',
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => _onRemoveMember(g),
      );
    }
  }
}
