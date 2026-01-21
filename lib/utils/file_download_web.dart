import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download using an in-memory blob.
Future<void> triggerFileDownload(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:$mimeType;base64,$base64Data';

  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement;
  anchor
    ..style.display = 'none'
    ..href = dataUrl
    ..download = filename;

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
