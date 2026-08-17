import 'dart:convert';
import 'dart:html' as html;

/// Web: dart:io não funciona no navegador, então disparamos o download
/// direto via um link Blob temporário. Não existe "caminho local" no
/// navegador, por isso devolve null.
Future<String?> saveCsv(String csvData, String filename) async {
  final bytes = utf8.encode(csvData);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
