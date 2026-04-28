import 'web_file_upload_picker_model.dart';

/// Non-web fallback. The Barcode -> EPC import screen is `kIsWeb` only and
/// returns early on mobile/desktop, so this code path is never actually
/// invoked in production.
///
/// We keep it dependency-free on purpose: any reference to `file_picker`
/// here used to bleed into web builds via the conditional import and was the
/// source of the recurring `Value must be finite: NaN` errors when the
/// runtime picked the stub instead of the real web implementation.
Future<PickedUploadFile?> pickFileForWebImport({
  required List<String> allowedExtensions,
}) async {
  return null;
}
