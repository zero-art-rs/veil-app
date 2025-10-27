import 'package:flutter/services.dart';
import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:markdown/markdown.dart' hide Document;
import 'package:printing/printing.dart';

class Markdown2PdfUtils {
  Markdown2PdfUtils._();

  static final Markdown2PdfUtils instance = Markdown2PdfUtils._();

  Future<Document> convert(String markdown) async {
    final pdfWidgets = await HTMLToPdf().convertMarkdown(markdown);
    // var data = await rootBundle.load("assets/open-sans.ttf");

    final document = Document(theme: ThemeData.base());
    document.addPage(MultiPage(build: (context) => pdfWidgets, pageFormat: PdfPageFormat.a4));

    return document;
  }
}
