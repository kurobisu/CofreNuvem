import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../utils/app_version.dart';
import '../utils/version_helper.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? releaseNotes;
  final String? sha256;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
    this.sha256,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      sha256: json['sha256'] as String?,
    );
  }

  bool get isNewer => VersionHelper.isNewer(version, appVersion);
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _envKey = 'UPDATE_CHECK_URL';

  /// Returns [UpdateInfo] when a newer version is available.
  /// Returns `null` when no update endpoint is configured or the app is up to date.
  Future<UpdateInfo?> checkForUpdate() async {
    final url = _checkUrl;
    if (url == null || url.isEmpty) {
      if (kDebugMode) debugPrint('[Updater] UPDATE_CHECK_URL not configured.');
      return null;
    }

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[Updater] Endpoint returned ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(body);

      if (kDebugMode) {
        debugPrint('[Updater] current=$appVersion remote=${info.version}');
      }

      return info.isNewer ? info : null;
    } catch (e, stack) {
      debugPrint('[Updater] Check failed: $e');
      debugPrint('$stack');
      return null;
    }
  }

  /// Downloads the installer to a temporary directory.
  /// [onProgress] receives values between 0.0 and 1.0.
  Future<String> downloadUpdate(
    String url, {
    required ValueChanged<double> onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = Uri.parse(url).pathSegments.lastOrNull ??
        'cofrenuvem_update_setup.exe';
    final filePath = '${tempDir.path}\\$fileName';
    final file = File(filePath);

    if (await file.exists()) await file.delete();

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    int received = 0;
    final sink = file.openWrite();

    await response.stream.map((chunk) {
      received += chunk.length;
      if (total > 0) onProgress(received / total);
      return chunk;
    }).pipe(sink);

    return filePath;
  }

  /// Launches the installer silently and exits the running app.
  /// The Inno Setup installer is responsible for closing/restarting the app.
  ///
  /// [expectedSha256], when provided by the update endpoint, is checked
  /// against the downloaded file before it runs. Releases published before
  /// this check existed carry an empty `sha256` in `latest.json`, so a
  /// missing/empty hash skips verification rather than blocking those
  /// updates.
  Future<void> installUpdate(String installerPath, {String? expectedSha256}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Auto-install is only supported on Windows');
    }

    final file = File(installerPath);
    if (!await file.exists()) {
      throw FileSystemException('Installer not found', installerPath);
    }

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final actualHash = sha256.convert(await file.readAsBytes()).toString();
      if (actualHash.toLowerCase() != expectedSha256.toLowerCase()) {
        await file.delete();
        throw Exception(
          'Verificação de integridade do instalador falhou (hash SHA-256 não confere). Atualização cancelada por segurança.',
        );
      }
    }

    final args = const [
      '/SILENT',
      '/SP-',
      '/SUPPRESSMSGBOXES',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
      '/NOCANCEL',
    ];

    await Process.start(installerPath, args, mode: ProcessStartMode.detached);

    // Give the installer a moment to acquire the mutex before terminating.
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  }

  String? get _checkUrl {
    try {
      final fromEnv = dotenv.env[_envKey];
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

      final fromPlatform = Platform.environment[_envKey];
      if (fromPlatform != null && fromPlatform.isNotEmpty) {
        return fromPlatform;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
