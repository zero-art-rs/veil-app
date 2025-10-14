import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:veil/api/group_api_client.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sharing/deeplink_manager.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pb.dart';
import 'package:veil/screens/contacts_page.dart';
import 'package:veil/storage/models.dart' as m;
import 'package:veil/storage/sqlite/db.dart';
import 'package:veil/utils/group_context_factory.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/ays_modal.dart';

class MemberScreenModel {
  final m.DocumentMember member;
  final bool isYou;
  final bool isOwner;

  MemberScreenModel({
    required this.member,
    this.isYou = false,
    this.isOwner = false,
  });
}

class DocumentMemberListScreen extends StatefulWidget {
  const DocumentMemberListScreen({
    super.key,
    required this.members,
    required this.syncModel,
  });

  final List<MemberScreenModel> members;
  final SyncModel syncModel;

  @override
  State<DocumentMemberListScreen> createState() =>
      _DocumentMemberListScreenState();
}

class _DocumentMemberListScreenState extends State<DocumentMemberListScreen> {
  void _onAddMember(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ContactsScreen(
          onPick: (account) async => _inviteContactMember(account),
        );
      },
    );
  }

  get currentAccountIsOwner {
    final owner = widget.members.firstWhereOrNull((e) {
      return e.isOwner && e.isYou;
    });

    return owner != null;
  }

  void showInviteDialog(Future<String> linkFuture) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return FutureBuilder<String>(
          future: linkFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text("Error"),
                content: Text("Failed to create invite link"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: !snapshot.hasData
                  ? Text("Constructing invite link...")
                  : Text('Copy link'),
              content: SizedBox(
                width: 480,
                child: !snapshot.hasData
                    ? Container(
                        alignment: Alignment.center,
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(),
                      )
                    : TextField(
                        controller: TextEditingController(text: snapshot.data),
                        readOnly: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
              ),
              actions: !snapshot.hasData
                  ? [Container()]
                  : [
                      Row(
                        spacing: 16,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: snapshot.data ?? ''),
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text('Copy'),
                            ),
                          ),
                        ],
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _removeMember(BuildContext context, m.DocumentMember user) {
    final work = Future<void>(() async {
      logger.i('Removing member in group context..');

      await widget.syncModel.removeMember(actorId: user.account.actorId);

      setState(() {
        widget.members.removeWhere(
          (e) => e.member.account.actorId == user.account.actorId,
        );
      });
    });

    aysAsyncModal(
      context: context,
      title: 'Are you sure to remove ${user.account.name} from group?',
      content: 'This action cannot be undone.',
      callback: () async {
        try {
          await work;
        } catch (e) {
          logger.e('Failed to remove member: $e');
          rethrow;
        }
      },
    );
  }

  void _inviteUndentifiedMember(BuildContext context) {
    final work = Future<String>(() async {
      try {
        return await widget.syncModel.createInviteLink();
      } catch (e) {
        logger.e('Failed to create invite link: $e');
        rethrow;
      }
    });

    showInviteDialog(work);
  }

  Future<void> _inviteContactMember(Contact contact) async {
    final future = Future(() async {
      // try {
      //   final firstSpk = contact.spks.firstOrNull;
      //   final spkPublicKey = firstSpk != null
      //       ? Uint8List.fromList(firstSpk)
      //       : null;

      //   final payload = Payload(
      //     crdt: CRDTPayload(fullDocument: widget.doc.automergeDoc.save()),
      //   ).writeToBuffer();

      //   logger.i('epoch ${await widget.syncModel.groupContext.epoch()}');

      //   final (frame, invite) = await widget.syncModel.groupContext
      //       .addIdentifiedMember(
      //         identityPublicKey: contact.account.rawPublicKey,
      //         spkPublicKey: spkPublicKey,
      //         payloads: [payload],
      //       );

      //   await GroupApiClient.instance.sendFrame(
      //     groupId: widget.doc.id,
      //     frame: frame,
      //   );

      //   logger.i('Member invite sent');
      //   final inviteLink = DeeplinkManager.instance.buildInvite(invite);

      //   await DB.instance.updateDocument(
      //     doc: widget.syncModel.document,
      //     parts: await widget.syncModel.groupContext.asParts(),
      //   );

      //   if (spkPublicKey != null) {
      //     logger.i('Removing spk contact spk..');
      //     await ContactsManager.instance.removeSpk(
      //       contact.account.actorId,
      //       spkPublicKey.toList(),
      //     );
      //   }

      //   return inviteLink;
      // } catch (e) {
      //   logger.e('Failed to invite member: $e');
      //   rethrow;
      // }
    });

    // showInviteDialog(future);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document members'),
        leading: PlatformUtils.isDesktop
            ? CloseButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              )
            : BackButton(),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.members.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Divider(height: 1, thickness: 1.2, color: dividerColor),
        ),
        itemBuilder: (context, i) {
          final g = widget.members[i];
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
              spacing: 12,
              children: [
                Text(
                  g.member.account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                if (g.isYou)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                g.member.account.actorId,
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          if (currentAccountIsOwner)
            FloatingActionButton(
              onPressed: () => _onAddMember(context),
              tooltip: 'Invite member',
              child: const Icon(Icons.person_add_alt_1_outlined),
            ),
          if (currentAccountIsOwner)
            FloatingActionButton(
              onPressed: () => _inviteUndentifiedMember(context),
              tooltip: 'Invite undentified member',
              child: const Icon(Symbols.domino_mask),
            ),
        ],
      ),
    );
  }

  Widget buildTrailing(ThemeData theme, MemberScreenModel g) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        if (currentAccountIsOwner && !g.isYou)
          IconButton(
            onPressed: () => _removeMember(context, g.member),
            icon: Icon(Icons.delete),
          ),

        if (g.isOwner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Owner',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
