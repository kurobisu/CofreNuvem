import 'package:sqlite3/sqlite3.dart';
void main() {
  final db = sqlite3.open('d:/Projetos Antigravity/CofreNuvem/db_maria.sqlite');
  final result = db.select('SELECT id, nome, auth_id FROM usuarios');
  for (final row in result) {
    print(row);
  }
}
