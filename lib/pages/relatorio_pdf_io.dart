import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

Future<pw.Font> loadPdfFontImpl() async {
  final fontPaths = <String>[];
  if (Platform.isWindows) {
    fontPaths.addAll([
      'C:\\Windows\\Fonts\\arial.ttf',
      'C:\\Windows\\Fonts\\calibri.ttf',
    ]);
  } else if (Platform.isLinux) {
    fontPaths.addAll([
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    ]);
  } else if (Platform.isMacOS) {
    fontPaths.addAll([
      '/Library/Fonts/Arial.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    ]);
  }

  for (final path in fontPaths) {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return pw.Font.ttf(ByteData.view(bytes.buffer));
    }
  }

  return pw.Font.helvetica();
}

Future<String> savePdfFileImpl(Uint8List bytes) async {
  // Helper para salvar via MediaStore (can return URI string)
  final methodChannel = const MethodChannel('appcanhoto/media_store');

  if (Platform.isAndroid) {
    final filename = 'relatorio-expresso-show-${DateTime.now().millisecondsSinceEpoch}.pdf';

    // Tenta salvar via MediaStore no Android para garantir que o arquivo esteja visível a outros apps.
    try {
      final uri = await methodChannel.invokeMethod<String>('saveFile', {
        'filename': filename,
        'bytes': bytes,
      });
      if (uri != null && uri.isNotEmpty) return uri;
    } catch (_) {
      // Continua para fallback
    }

    // Pode precisar de permissão de storage em dispositivos mais antigos para gravar em Download.
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    } catch (_) {
      // Ignora falha na solicitação de permissão.
    }

    // Fallback: escrever diretamente na pasta pública Download
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      // Se tudo falhar, gravar nos documentos do app
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  // Desktop, iOS and other platforms
  Directory directory;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  final file = File('${directory.path}${Platform.pathSeparator}relatorio-expresso-show-${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> openPdfFileImpl(String path) async {
  try {
    final uri = path.startsWith('content://')
        ? Uri.parse(path)
        : Uri.file(path);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Falha ao abrir arquivo PDF: $e');
  }
}
