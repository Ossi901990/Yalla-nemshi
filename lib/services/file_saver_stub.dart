import 'dart:typed_data';

Future<void> Function(Uint8List, String, String) createFileSaver() {
  return (bytes, filename, mime) async {
    throw UnsupportedError('File saving is not supported on this platform');
  };
}
