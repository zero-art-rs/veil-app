import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zk_notion_app/api/client.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/managers/deeplink_manager.dart';
import 'package:zk_notion_app/protos/zero_art.pb.dart';
import 'package:zk_notion_app/screens/contacts_page.dart';
import 'package:zk_notion_app/src/rust/api/group_context.dart';
import 'package:zk_notion_app/storage/models.dart' as m;
import 'package:zk_notion_app/storage/sqlite/db.dart';
import 'package:zk_notion_app/utils/secret_factory.dart';
import 'package:zk_notion_app/widgets/banner.dart';
import 'package:zk_notion_app/utils/platform.dart';

class MemberScreenModel {
  final m.DocumentMember member;
  final bool isYou;

  MemberScreenModel({required this.member, this.isYou = false});
}

class DocumentMemberListScreen extends StatefulWidget {
  const DocumentMemberListScreen({
    super.key,
    required this.members,
    required this.doc,
    required this.groupContext,
  });

  final List<MemberScreenModel> members;
  final BGroupContext groupContext;

  final m.Document doc;

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
                  : Text('Copy untrusted link'),
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

  Future<void> _inviteUndentifiedMember(BuildContext context) async {
    final inviteLink = Future(() async {
      final secretKey = SecretManager.intance.generateSecretKey();

      final payload = Payload(
        crdt: CRDTPayload(fullDocument: widget.doc.automergeDoc.save()),
      ).writeToBuffer();

      logger.i('Creating unidentified member invite...');
      final (frame, invite) = await widget.groupContext.addUnidentifiedMember(
        secretKey: secretKey,
        payloads: [payload],
      );
      logger.i('Finished creating unidentified member invite...');

      logger.i('Sending unidentified member invite frame...');
      await GroupApiClient.instance.sendFrame(
        groupId: widget.doc.id,
        frame: frame,
      );
      logger.i('Finished sending unidentified member invite frame...');

      final inviteLink = DeeplinkManager.instance.buildUnidentifiedGroupInvite(
        invite,
      );

      return inviteLink;
    });

    showInviteDialog(inviteLink);
  }

  Future<void> _inviteContactMember(m.ExternalAccount member) async {
    try {
      // LOGIC

      // setState(() {
      //   widget.doc.members.add(
      //     m.DocumentMember(account: member, isOwner: false),
      //   );
      //   widget.members.add(
      //     MemberScreenModel(
      //       member: m.DocumentMember(account: member, isOwner: false),
      //     ),
      //   );
      // });

      if (!mounted) return;
      Navigator.pop(context);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        if (!mounted) return;

        TopBanner.show(
          context: context,
          message: 'Member already exists',
          kind: TopBannerCases.info,
        );
      } else {
        logger.e('Failed to add member: $e');
        if (!mounted) return;
        TopBanner.show(
          context: context,
          message: 'Failed to add member, try again',
          kind: TopBannerCases.error,
        );
      }
    } catch (err) {
      logger.e('Failed to add member: $err');
      if (!mounted) return;
      TopBanner.show(
        context: context,
        message: 'Unexpected error, try again',
        kind: TopBannerCases.error,
      );
    }
  }

  void _onRemoveMember(MemberScreenModel g) async {
    // await DB.instance.deleteMember(g.member.account.actorId);
    setState(() => widget.members.remove(g));

    widget.doc.members.removeWhere(
      (e) => e.account.actorId == g.member.account.actorId,
    );
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
              children: [
                Expanded(
                  child: Text(
                    g.member.account.name,
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
          FloatingActionButton(
            onPressed: () => _onAddMember(context),
            tooltip: 'Invite member',
            child: const Icon(Icons.person_add_alt_1_outlined),
          ),

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
