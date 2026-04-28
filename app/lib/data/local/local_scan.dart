/// Mirrors the `scans.kind` enum on the server (migration `006_scans_kind`).
/// The Task UI uses these to split scans into 3 tabs.
class ScanKind {
  /// Mobile camera scan or manual barcode entry (default for legacy rows).
  static const String barcodeScan = 'barcode_scan';

  /// Web upload of a packing list / Excel that gets converted to SGTIN-96.
  static const String epcImport = 'epc_import';

  /// UHF RFID tag read by the C5 hand reader (or imported from one of its
  /// EPC dump files).
  static const String epcRead = 'epc_read';

  /// All values the server accepts. Anything else is normalized to
  /// [barcodeScan] both here and in `ScanRepository._normalizeKind`.
  static const Set<String> all = {barcodeScan, epcImport, epcRead};

  static String normalize(String? raw) {
    if (raw == null) return barcodeScan;
    final v = raw.trim();
    return all.contains(v) ? v : barcodeScan;
  }
}

/// Local scan record for offline queue (simple model, no Drift for now).
class LocalScan {
  LocalScan({
    required this.id,
    required this.projectId,
    required this.barcodeValue,
    this.barcodeFormat,
    required this.scannedAt,
    this.notes,
    this.username,
    this.synced = false,
    this.error,
    this.sendId,
    this.batchName,
    this.sourceFile,
    String? kind,
  }) : kind = ScanKind.normalize(kind);

  final String id;
  final String projectId;
  final String barcodeValue;
  final String? barcodeFormat;
  final DateTime scannedAt;
  final String? notes;
  final String? username;
  final bool synced;
  final String? error;
  final String? sendId;
  final String? batchName;
  final String? sourceFile;

  /// One of [ScanKind.barcodeScan], [ScanKind.epcImport], [ScanKind.epcRead].
  /// Legacy rows that don't carry a kind are normalized to `barcode_scan` so
  /// they show up under the "Scan + manual" tab.
  final String kind;

  Map<String, dynamic> toApiJson() => {
        'project_id': projectId,
        'barcode_value': barcodeValue,
        if (barcodeFormat != null) 'barcode_format': barcodeFormat,
        'scanned_at': scannedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
        'kind': kind,
        'metadata': {
          if (sendId != null && sendId!.trim().isNotEmpty) 'send_id': sendId,
          if (batchName != null && batchName!.trim().isNotEmpty)
            'batch_name': batchName,
          if (sourceFile != null && sourceFile!.trim().isNotEmpty)
            'source_file': sourceFile,
        },
      };

  LocalScan copyWith({
    bool? synced,
    String? error,
    String? barcodeValue,
    String? projectId,
    String? sendId,
    String? batchName,
    String? sourceFile,
    String? kind,
    bool clearError = false,
  }) =>
      LocalScan(
        id: id,
        projectId: projectId ?? this.projectId,
        barcodeValue: barcodeValue ?? this.barcodeValue,
        barcodeFormat: barcodeFormat,
        scannedAt: scannedAt,
        notes: notes,
        username: username,
        synced: synced ?? this.synced,
        error: clearError ? null : (error ?? this.error),
        sendId: sendId ?? this.sendId,
        batchName: batchName ?? this.batchName,
        sourceFile: sourceFile ?? this.sourceFile,
        kind: kind ?? this.kind,
      );
}
