import 'package:flutter/material.dart';
import 'package:zk_notion_app/screens/account_page.dart';
import 'package:zk_notion_app/screens/doc_members.dart';
import 'package:zk_notion_app/screens/editor_page.dart';
import 'package:zk_notion_app/screens/history_page.dart';
import 'package:zk_notion_app/storage/account_storage.dart';
import 'package:zk_notion_app/storage/document_storage.dart';
import 'package:zk_notion_app/storage/models.dart';
import 'package:zk_notion_app/utils/banner.dart';

import '../../main.dart';

class PrimaryPageViewModel extends ChangeNotifier {
  final _docStorage = DocumentStorage();
  final _accStorage = AccountStorage();

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  Widget _selectedPage = AccountPage();
  Widget get selectedPage => _selectedPage;

  List<Document> _docs = [];
  List<Document> get docs => _docs;

  final TextEditingController textEditingController = TextEditingController();

  static const constantTabs = 5;

  void init() async {
    _docs = await _docStorage.getDocuments();
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    setSelectedPage();
    notifyListeners();
  }

  void createDocument(BuildContext context) async {
    try {
      final resTitle = textEditingController.text.isEmpty
          ? 'Document'
          : textEditingController.text;
      final owner = await _accStorage.getAccount();

      if (owner == null) {
        throw Exception('To create a document, you must have account');
      }

      final doc = await _docStorage.createDocument(
        title: resTitle,
        owner: DocumentMember(
          account: ExternalAccount.fromAccount(owner),
          isOwner: true,
        ),
      );

      textEditingController.clear();
      _docs.add(doc);

      notifyListeners();
    } catch (err) {
      logger.e('Failed to create document: $err');
      if (!context.mounted) return;
      TopBanner.show(
        context: context,
        message: 'Failed to create document',
        kind: TopBannerCases.error,
      );
    }
  }

  void setSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        _selectedPage = AccountPage();
      case 1:
        _selectedPage = Center(
          child: Text('Contacts', style: TextStyle(color: Colors.black)),
        );
      default:
        final doc = _docs[_selectedIndex - constantTabs];
        _selectedPage = EditorPage(key: ValueKey(doc.id), doc: doc);
    }

    notifyListeners();
  }

  removeDocument(BuildContext context, String id) async {
    try {
      await _docStorage.removeDocument(id);

      _docs.removeWhere((element) => element.id == id);
      _selectedIndex = 0;

      setSelectedPage();
      notifyListeners();
    } catch (err) {
      logger.e('Failed to remove document: $err');
      if (!context.mounted) return;

      TopBanner.show(
        context: context,
        message: 'Failed to remove document',
        kind: TopBannerCases.error,
      );
    }
  }

  Future<List<MemberScreenModel>> prepareMembers() async {
    final account = await _accStorage.getAccount();
    return _docs[selectedIndex - constantTabs].members
        .map(
          (e) => MemberScreenModel(
            member: e,
            isYou: e.account.actorId == account?.actorId,
          ),
        )
        .toList();
  }

  (List<ChangeEvent>, Document) prepareChanges() {
    final doc = _docs[selectedIndex - constantTabs];

    final changes = doc.automergeDoc
        .getChangeList()
        .indexed
        .map(
          (e) => ChangeEvent(
            title: 'Change',
            actorIdHex: e.$2.actorIdHex(),
            changeHashHex: e.$2.changeHash(),
            date: e.$2.timestamp(),
            isInitial: e.$1 == 0,
          ),
        )
        .toList()
        .reversed
        .toList();

    return (changes, doc);
  }
}
