import 'dart:io';

import 'package:flutter/material.dart';

import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      final installerPath = await UpdateService().downloadUpdate(
        widget.updateInfo.downloadUrl,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );

      if (!mounted) return;

      await UpdateService().installUpdate(
        installerPath,
        expectedSha256: widget.updateInfo.sha256,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = 'Falha ao baixar/atualizar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova versão disponível'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CofreNuvem ${widget.updateInfo.version} está disponível.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (widget.updateInfo.releaseNotes != null)
              Text(widget.updateInfo.releaseNotes!),
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}% baixado'),
            ],
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Depois'),
        ),
        ElevatedButton(
          onPressed: _isDownloading ? null : _downloadAndInstall,
          child: const Text('Atualizar agora'),
        ),
      ],
    );
  }
}

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  if (!Platform.isWindows) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDialog(updateInfo: info),
  );
}
