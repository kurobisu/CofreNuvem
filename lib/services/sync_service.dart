import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// O package google_sign_in não tem suporte oficial para Windows (Desktop).
// A implementação abaixo está mockada para permitir a compilação no Windows.
// Em um ambiente de produção real (Mobile/Android/iOS), utilizaríamos os imports 
// de 'package:google_sign_in/google_sign_in.dart' e 'package:googleapis/drive/v3.dart'.

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

class SyncService {
  static const String _dbFileName = 'cofrenuvem.db';

  bool get isConnected => false; // Mocado

  Future<bool> signIn() async {
    debugPrint('Google Sign-In não suportado no Windows. Função simulada.');
    return false;
  }

  Future<void> signOut() async {
    debugPrint('Sign-Out simulado.');
  }

  Future<void> syncDatabase() async {
    debugPrint('Sincronização abortada: Google Sign-In indisponível.');
  }

  Future<void> uploadLocalDatabase() async {
    debugPrint('Upload abortado: Google Sign-In indisponível.');
  }
}
