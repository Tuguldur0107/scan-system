import 'dart:typed_data';

class PickedUploadFile {
  const PickedUploadFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}
