import 'dart:typed_data';

import '../utils/file_download_stub.dart'
    if (dart.library.html) '../utils/file_download_web.dart';

Future<void> Function(Uint8List, String, String) createFileSaver() {
  return (Uint8List bytes, String filename, String mimeType) async {
    await triggerFileDownload(bytes, filename, mimeType);
  };
}
