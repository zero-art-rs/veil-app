import 'package:rxdart/subjects.dart';
import 'package:veil/storage/models.dart';
import 'package:veil/storage/sqlite/db.dart';

class DocumentsRepo {
  static final DocumentsRepo instance = DocumentsRepo();
  final _db = DB.instance;
  final subject = BehaviorSubject<List<Document>>.seeded([]);

  List<Document> get current => subject.value;
  Stream<List<Document>> get stream => subject.stream;

  Future<void> loadDocuments() async {
    final docs = await _db.getDocumentList();
    subject.value = docs;
    subject.add(current);
  }

  void addDocument(Document document) async {
    await _db.insertDocument(document: document);
    current.add(document);
    subject.add(current);
  }

  void removeDocument(Document document) {
    current.remove(document);
    subject.add(current);
  }
}
