import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> Function(Uint8List, String, String) createFileSaver() {
  return (Uint8List bytes, String filename, String mimeType) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: mimeType,
          name: filename,
        ),
      ],
      subject: 'Walk export from Yalla Nemshi',
    );
  };
}
