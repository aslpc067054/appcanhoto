from pathlib import Path

path = Path('lib/pages/relatorio_page.dart')
text = path.read_text(encoding='utf-8')
old = """  Future<pw.Font> _loadPdfFont() async {
    return loadPdfFont();
      fontPaths.addAll([
        'C:\Windows\Fonts\arial.ttf',
        'C:\Windows\Fonts\calibri.ttf',
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

  }
"""
new = """  Future<pw.Font> _loadPdfFont() async {
    return loadPdfFont();
  }

  Future<void> _gerarPdf() async {
"""
if old not in text:
    print('old-not-found')
    raise SystemExit(1)
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('replaced')
