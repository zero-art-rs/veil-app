import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:veil/extensions/group_context.dart';
import 'package:veil/main.dart';
import 'package:veil/managers/contacts_manager.dart';
import 'package:veil/managers/sync_provider/events.dart';
import 'package:veil/managers/sync_provider/sync_model.dart';
import 'package:veil/protos/zero_art.pbserver.dart';
import 'package:veil/screens/contacts_page.dart';
import 'package:veil/storage/account_storage.dart';
import 'package:veil/storage/models/document_member.dart';
import 'package:veil/storage/models/external_account.dart';
import 'package:veil/storage/sqlite/consts.dart';
import 'package:veil/utils/platform.dart';
import 'package:veil/widgets/ays_modal.dart';
import 'package:veil/widgets/banner.dart';
import 'package:veil/widgets/loader_dialog.dart';

const _pendingForRemovalStatus = 3;
const _wantsToLeaveStatus = 2;
const _invitedStatus = 1;
const _inGroupStatus = 0;

class MemberScreenModel {
  final DocumentMember member;
  final bool isYou;
  final bool isOwner;

  MemberScreenModel({
    required this.member,
    this.isYou = false,
    this.isOwner = false,
  });
}

class DocumentMemberListScreen extends StatefulWidget {
  DocumentMemberListScreen({
    super.key,
    required this.syncModel,
    this.onBackPressed,
  });

  final SyncModel syncModel;
  final void Function()? onBackPressed;

  final updateUserNameTextController = TextEditingController();

  @override
  State<DocumentMemberListScreen> createState() =>
      _DocumentMemberListScreenState();
}

class _DocumentMemberListScreenState extends State<DocumentMemberListScreen> {
  StreamSubscription? _groupInfoUpdates;
  var members = <MemberScreenModel>[];

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

  List<MemberScreenModel> _prepareMemberList(GroupInfo groupInfo) {
    final members = groupInfo.members
        .map(
          (e) => MemberScreenModel(
            member: DocumentMember(
              account: ExternalAccount(
                actorId: e.id,
                name: e.name,
                rawPublicKey: e.publicKey,
              ),
              status: e.status.value,
              role: e.role.value,
              roleName: e.role.name,
            ),
            isYou: AccountSecureStorage.instance.account.actorId == e.id,
            isOwner: e.role.value == ownerRole,
          ),
        )
        .toList();

    return members;
  }

  @override
  void initState() {
    super.initState();

    members = _prepareMemberList(
      widget.syncModel.groupContext.retrieveGroupInfo(),
    );

    _groupInfoUpdates = widget.syncModel.eventStream.listen((e) {
      if (e is SyncModelGroupInfoEvent) {
        setState(() {
          members = _prepareMemberList(e.groupInfo);
        });
      }
    });
  }

  @override
  void dispose() {
    _groupInfoUpdates?.cancel();
    super.dispose();
  }

  get currentAccountIsOwner {
    final owner = members.firstWhereOrNull((e) {
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

  Future<void> _removeMember(BuildContext context, DocumentMember user) async {
    await aysAsyncModal(
      context: context,
      title: 'Are you sure to remove ${user.account.name} from group?',
      content: 'This action cannot be undone.',
      callback: () async {
        try {
          logger.info('Removing member in group context..');

          await widget.syncModel.removeMember(actorId: user.account.actorId);

          setState(() {
            members.removeWhere(
              (e) => e.member.account.actorId == user.account.actorId,
            );
          });
        } catch (e, st) {
          logger.error('Failed to remove member', e, st);
          if (!context.mounted) return;
          TopBanner.show(
            context: context,
            message: 'Failed to remove member',
            kind: TopBannerCases.error,
          );
          rethrow;
        }
      },
    );
  }

  Future<void> _openChangeNameModal() async {
    final style = Theme.of(context).textTheme;

    await showLoaderDialog(
      context: context,
      work: () async {
        try {
          await widget.syncModel.updateUserName(
            name: widget.updateUserNameTextController.text,
          );
        } catch (e, st) {
          if (!mounted) return;
          logger.error('Failed to update name', e, st);
          TopBanner.show(
            context: context,
            message: 'Failed to update name',
            kind: TopBannerCases.error,
          );
        } finally {
          widget.updateUserNameTextController.clear();
        }
      },
      initialBuilder: (context, start) => SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text('Update your name in group', style: style.titleLarge),
            ),

            TextField(
              controller: widget.updateUserNameTextController,
              decoration: InputDecoration(label: Text('Input your new name')),
            ),

            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      start();
                    },
                    child: Text('Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _inviteUndentifiedMember(BuildContext context) {
    final work = Future<String>(() async {
      try {
        return await widget.syncModel.createUnidentifiedMemberInviteLink();
      } catch (e, st) {
        logger.error('Failed to create unidentified invite link', e, st);
        rethrow;
      }
    });

    showInviteDialog(work);
  }

  Future<void> _inviteContactMember(Contact contact) async {
    final future = Future(() async {
      try {
        return await widget.syncModel.createIdentifiedMemberLink(
          contact: contact,
        );
      } catch (e, st) {
        logger.error('Failed to create indentified invite link', e, st);
        rethrow;
      }
    });

    showInviteDialog(future);
  }

  String status(int status) {
    switch (status) {
      case _inGroupStatus:
        return 'In group';
      case _invitedStatus:
        return 'Invited';
      case _wantsToLeaveStatus:
        return 'Wants to leave';
      case _pendingForRemovalStatus:
        return 'Pending for removal confrimation';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document members'),
        leading: PlatformUtils.isDesktop
            ? CloseButton(onPressed: () => widget.onBackPressed?.call())
            : BackButton(),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: members.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Divider(height: 1, thickness: 1.2, color: dividerColor),
        ),
        itemBuilder: (context, i) {
          final g = members[i];
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
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
                Text(
                  'Status: ${status(g.member.status)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
      children: [
        if (g.isYou)
          IconButton(
            onPressed: () async => await _openChangeNameModal(),
            icon: Icon(Icons.edit),
          ),

        if ((currentAccountIsOwner && !g.isYou) ||
            (!g.isYou && g.member.status == _pendingForRemovalStatus))
          IconButton(
            onPressed: () async => await _removeMember(context, g.member),
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
