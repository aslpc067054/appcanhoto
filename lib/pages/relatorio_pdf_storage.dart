import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import 'relatorio_pdf_io.dart'
    if (dart.library.html) 'relatorio_pdf_storage_web.dart';

Future<pw.Font> loadPdfFont() => loadPdfFontImpl();
Future<String> savePdfFile(Uint8List bytes) => savePdfFileImpl(bytes);
Future<void> openPdfFile(String path) => openPdfFileImpl(path);
