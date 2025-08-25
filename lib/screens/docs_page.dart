import 'package:flutter/material.dart';

class DocsUiOnlyPage extends StatelessWidget {
  const DocsUiOnlyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.description_outlined),
            const SizedBox(width: 12),
            Text('Docs', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create document tapped')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create document'),
      ),
      body: docs.isEmpty ? _NodocumentsYet() : GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10, // одинаковый spacing
          childAspectRatio: 1,
        ),
        itemCount: docs.length,
        itemBuilder: (context, i) => _DocCard(doc: docs[i]),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});
  final _Doc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shadowColor: Colors.black,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Open "${doc.title}" (UI only)')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Opacity(
                          opacity: 0.5,
                          child: Icon(
                            Icons.description,
                            size: 64,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodocumentsYet extends StatelessWidget {
  const _NodocumentsYet({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "No documents currently",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _Doc {
  final String title;
  final String subtitle; // e.g., "Edited 2 hours ago"
  final String owner;
  final int pages;

  const _Doc({
    required this.title,
    required this.subtitle,
    required this.owner,
    required this.pages,
  });
}

const _mockDocs = <_Doc>[
  _Doc(
    title:
        'Project Plan Q3Project Plan Q3Project Plan Q3Project Plan Q3Project Plan Q3Project Plan Q3',
    subtitle: 'Edited 2 hours ago',
    owner: 'You',
    pages: 3,
  ),
  _Doc(
    title: 'Meeting Notes — Design Sync',
    subtitle: 'Edited yesterday',
    owner: 'Alice',
    pages: 2,
  ),
  _Doc(
    title: 'Product Requirements v1.2',
    subtitle: 'Edited Aug 10',
    owner: 'Bob',
    pages: 6,
  ),
  _Doc(
    title: 'Onboarding Checklist',
    subtitle: 'Edited last week',
    owner: 'Carol',
    pages: 1,
  ),
  _Doc(
    title: 'Marketing Brief (Draft)',
    subtitle: 'Edited 3 days ago',
    owner: 'You',
    pages: 4,
  ),
  _Doc(
    title: 'Team Retrospective',
    subtitle: 'Edited 2 weeks ago',
    owner: 'You',
    pages: 5,
  ),
  _Doc(
    title: 'iOS App Copy — Ukrainian',
    subtitle: 'Edited Aug 1',
    owner: 'Alice',
    pages: 7,
  ),
  _Doc(
    title: 'Security Review Notes',
    subtitle: 'Edited Jul 30',
    owner: 'Bob',
    pages: 2,
  ),
  _Doc(
    title: 'Sprint Planning 34',
    subtitle: 'Edited Jul 29',
    owner: 'Carol',
    pages: 3,
  ),
  _Doc(
    title: 'Watch Swap UX Wireframes',
    subtitle: 'Edited Jul 25',
    owner: 'You',
    pages: 8,
  ),
  _Doc(
    title: 'API Spec — Notifications',
    subtitle: 'Edited Jul 21',
    owner: 'Bob',
    pages: 5,
  ),
  _Doc(
    title: 'Localization Keys (EN/UK)',
    subtitle: 'Edited Jul 18',
    owner: 'You',
    pages: 9,
  ),
];

/* -------------------------- Usage ----------------------------- */
// MaterialApp(home: DocsUiOnlyPage())
