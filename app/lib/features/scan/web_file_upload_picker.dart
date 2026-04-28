// We default to the web implementation and only swap in the no-op stub on
// platforms that have `dart:io` (Android, iOS, Windows, macOS, Linux). This
// is more reliable than checking `dart.library.html`, which can be missing
// on some web runtimes (notably dart2wasm) and would cause the build to
// silently fall back to the stub.
import 'web_file_upload_picker_web.dart'
    if (dart.library.io) 'web_file_upload_picker_stub.dart' as impl;
import 'web_file_upload_picker_model.dart';

Future<PickedUploadFile?> pickFileForWebImport({
  required List<String> allowedExtensions,
}) {
  return impl.pickFileForWebImport(allowedExtensions: allowedExtensions);
}
