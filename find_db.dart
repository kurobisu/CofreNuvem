import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  String dbPath = await dbFactory.getDatabasesPath();
  print('DB PATH: \$dbPath');
}
