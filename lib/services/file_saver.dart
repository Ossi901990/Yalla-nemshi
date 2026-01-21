import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web_impl.dart'
    if (dart.library.io) 'file_saver_io_impl.dart';

typedef _SaveFn = Future<void> Function(
  Uint8List bytes,
  String filename,
  String mimeType,
);

final _SaveFn _delegate = createFileSaver();

/// Cross-platform helper for saving or sharing generated files.
class FileSaver {
  const FileSaver._();

  static Future<void> saveBytes(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) {
    return _delegate(bytes, filename, mimeType);
  }
}
