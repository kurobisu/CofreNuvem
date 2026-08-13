import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var factory = databaseFactoryFfi;
  
  var db2 = await factory.openDatabase('d:/Projetos Antigravity/CofreNuvem/db2_new.db');
  var trans = await db2.query('transacoes');
  print('Transações do Clovis:');
  for (var t in trans) {
    print(t);
  }
  exit(0);
}
