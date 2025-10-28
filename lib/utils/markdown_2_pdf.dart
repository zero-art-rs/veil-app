import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';

class Markdown2PdfUtils {
  Markdown2PdfUtils._();

  static final Markdown2PdfUtils instance = Markdown2PdfUtils._();

  Future<Document> convert(String markdown) async {
    final pdfWidgets = await HTMLToPdf().convertMarkdown(markdown);

    final document = Document(theme: ThemeData.base());
    document.addPage(
      MultiPage(
        build: (context) => pdfWidgets.isEmpty ? [Container()] : pdfWidgets,
        pageFormat: PdfPageFormat.a4,
      ),
    );

    return document;
  }
}
