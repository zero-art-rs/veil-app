import 'package:flutter/material.dart';
import 'package:popover/popover.dart';
import 'package:zk_notion_app/main.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/editor_page.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart' as models;
import 'package:zk_notion_app/utils/banner.dart';
import 'package:zk_notion_app/widgets/sidebar.dart';

class DesktopPrimaryPage extends StatefulWidget {
  const DesktopPrimaryPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return StateDesktopPrimaryPage();
  }
}

class StateDesktopPrimaryPage extends State<DesktopPrimaryPage> {
  final _docStorage = DocumentStorage();
  final _accStorage = AccountStorage();

  List<models.Document> _docs = [];
  int _selectedIndex = 0;
  Widget _selectedPage = Container();
  final _textFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _setSelectedPage();
    _init();
  }

  _init() async {
    final docs = await _docStorage.getDocuments();
    logger.d('Documents: ${docs.length}');
    setState(() {
      _docs = docs;
    });
  }

  void _setSelectedPage() {
    final constantTabs = 5;

    setState(() {
      switch (_selectedIndex) {
        case 0:
          _selectedPage = Center(
            child: Text('Home', style: TextStyle(color: Colors.black)),
          );
        case 1:
          _selectedPage = Center(
            child: Text('Contacts', style: TextStyle(color: Colors.black)),
          );
        default:
          final doc = _docs[_selectedIndex - constantTabs];
          _selectedPage = EditorPage(key: ValueKey(doc.id), doc: doc);
      }
    });
  }

  _createDocument(String title) async {
    final resTitle = title.isEmpty ? 'Document' : title;

    try {
      final owner = await _accStorage.getAccount();

      if (owner == null) {
        throw 'To create a document, you must have account';
      }

      final doc = await _docStorage.createDocument(
        title: resTitle,
        owner: models.DocumentMember(
          account: models.ExternalAccount.fromAccount(owner),
          isOwner: true,
        ),
      );

      setState(() {
        _textFieldController.clear();
        _docs.add(doc);
      });
    } catch (err) {
      if (!mounted) return;
      TopBanner.show(
        context: context,
        message: 'Failed to create document',
        kind: TopBannerCases.error,
      );
      logger.e('Failed to create document: $err');
    }
  }

  _removeDocument(String id) async {
    try {
      await _docStorage.removeDocument(id);

      setState(() {
        _docs.removeWhere((element) => element.id == id);
      });
    } catch (err) {
      if (!mounted) return;
      TopBanner.show(
        context: context,
        message: 'Failed to remove document',
        kind: TopBannerCases.error,
      );
      logger.e('Failed to remove document: $err');
    }
  }

  void _showCreateDocumentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create document'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: _textFieldController,
              decoration: InputDecoration(label: Text('Input document title')),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await _createDocument(_textFieldController.text);
                _textFieldController.clear();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.onSurface,
      body: Row(
        children: [
          SideNav(
            extended: true,
            entries: [
              SideNavItem(icon: Icons.home, label: 'Home'),
              SideNavItem(icon: Icons.group, label: 'Contacts'),
              SideNavSpace(24),
              SideNavHeader(
                label: 'Documents',
                trailingBuilder: () => InkWell(
                  child: Icon(Icons.add, size: 16),
                  onTap: () => {_showCreateDocumentModal(context)},
                ),
              ),
              SideNavDivider(),
              ..._docs.map(
                (doc) => SideNavItem(
                  icon: Icons.description_outlined,
                  label: doc.title,
                  trailingBuilder: () => IconButton(
                    onPressed: () async => await _removeDocument(doc.id),
                    icon: Icon(Icons.remove, size: 14),
                  ),
                ),
              ),
            ],
            onSelected: (value) => {
              setState(() {
                _selectedIndex = value;
                _setSelectedPage();
              }),
            },
            selectedIndex: _selectedIndex,
          ),
          Expanded(
            child: Stack(
              children: [
                _selectedPage,

                // Кнопка в правом нижнем углу
                Container(
                  margin: const EdgeInsets.all(16),
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    width: 60,
                    height: 60,

                    child: Builder(
                      builder: (buttonCtx) => ElevatedButton(
                        onPressed: () {
                          showPopover(
                            context: buttonCtx,
                            direction: PopoverDirection.top,
                            transition: PopoverTransition.other,
                            width: 360,
                            height: 680,
                            arrowWidth: 0,
                            arrowDyOffset: 80,
                            backgroundColor: Colors.white,
                            barrierColor: Colors.black26,

                            bodyBuilder: (ctx) => Material(
                              color: Colors.white,
                              child: DocumentMemberListScreen(
                                members: _docs[_selectedIndex - 5].members
                                    .map((e) => MemberScreenModel(member: e))
                                    .toList(),
                                doc: _docs[_selectedIndex - 5],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Icon(Icons.group_outlined, size: 24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
