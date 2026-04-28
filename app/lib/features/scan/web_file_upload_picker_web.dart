// Web-only file picker built on `package:web` so it works under both
// dart2js (default `flutter run -d chrome`) and dart2wasm. We deliberately
// avoid `package:file_picker` here: its web implementation reads the file
// through a progress-reporting wrapper that triggers
// `Invalid argument(s): Value must be finite: NaN` for some browsers when
// the browser does not report a length.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_file_upload_picker_model.dart';

Future<PickedUploadFile?> pickFileForWebImport({
  required List<String> allowedExtensions,
}) async {
  final input = web.HTMLInputElement();
  input.type = 'file';
  input.multiple = false;
  input.style.display = 'none';

  if (allowedExtensions.isNotEmpty) {
    final accept = allowedExtensions
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .map((e) => e.startsWith('.') ? e : '.$e')
        .join(',');
    input.accept = accept;
  }

  final completer = Completer<PickedUploadFile?>();
  void completeOnce(PickedUploadFile? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  Future<void> readSelected() async {
    // Some browsers fire `change` before `files` is fully populated.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final files = input.files;
    if (files == null || files.length == 0) {
      return;
    }
    final file = files.item(0);
    if (file == null) {
      return;
    }

    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      // Defensive copy so the underlying ArrayBuffer can't be detached
      // out from under us by the browser/runtime.
      completeOnce(
        PickedUploadFile(
          name: file.name,
          bytes: Uint8List.fromList(bytes),
        ),
      );
    } catch (_) {
      completeOnce(null);
    }
  }

  void onChange(web.Event _) {
    readSelected();
  }

  final listener = onChange.toJS;
  input.addEventListener('change', listener);
  input.addEventListener('input', listener);

  // Some browsers refuse to surface the picked file unless the input is
  // attached to the DOM at the time of the click.
  web.document.body?.appendChild(input);
  input.click();

  PickedUploadFile? picked;
  try {
    picked = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => null,
    );
  } finally {
    input.removeEventListener('change', listener);
    input.removeEventListener('input', listener);
    input.remove();
  }
  return picked;
}
