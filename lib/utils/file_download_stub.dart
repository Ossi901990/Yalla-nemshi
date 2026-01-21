import 'dart:typed_data';

/// No-op placeholder used on non-web platforms.
Future<void> triggerFileDownload(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {}
