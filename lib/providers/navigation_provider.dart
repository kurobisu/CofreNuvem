import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aba atual do MainScreen. Vive num provider (em vez de State local) pra
/// que outras partes do app -- não só o MainScreen -- consigam ler ou trocar
/// a aba ativa (ex.: navegar direto pra aba Compras a partir de outra tela).
class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
}

final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(
  CurrentTabNotifier.new,
);
