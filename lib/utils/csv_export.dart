/// Exporta CSV pra download/arquivo local, com implementação escolhida em
/// tempo de compilação: `dart:io` (grava arquivo local) em desktop/mobile,
/// `dart:html` (dispara download do navegador) na web.
export 'csv_export_io.dart' if (dart.library.html) 'csv_export_web.dart';
