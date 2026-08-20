// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

Future<pw.Font> loadPdfFontImpl() async => pw.Font.helvetica();

Future<String> savePdfFileImpl(Uint8List bytes) async {
  final filename = 'relatorio-expresso-show-${DateTime.now().millisecondsSinceEpoch}.pdf';
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return filename;
}

Future<void> openPdfFileImpl(String path) async {
  // No-op on web: o arquivo já foi enviado ao usuário como download.
}
