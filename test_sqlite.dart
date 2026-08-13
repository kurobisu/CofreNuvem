import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  var factory = databaseFactoryFfi;
  
  var db1 = await factory.openDatabase('d:/Projetos Antigravity/CofreNuvem/db1.db');
  var users1 = await db1.query('usuarios');
  print('DB1 (86b04138...) Users: $users1');
  
  var db2 = await factory.openDatabase('d:/Projetos Antigravity/CofreNuvem/db2.db');
  var users2 = await db2.query('usuarios');
  print('DB2 (abe6bae9...) Users: $users2');
  
  var transactions1 = await db1.query('transacoes');
  print('DB1 Transactions: $transactions1');

  var transactions2 = await db2.query('transacoes');
  print('DB2 Transactions: $transactions2');

  exit(0);
}
