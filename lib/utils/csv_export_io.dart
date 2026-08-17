import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Desktop/mobile: grava o CSV num arquivo local e devolve o caminho.
Future<String?> saveCsv(String csvData, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/$filename';
  final file = File(path);
  await file.writeAsString(csvData);
  return path;
}
