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
  });

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

  Map<String, dynamic> toApiJson() => {
        'project_id': projectId,
        'barcode_value': barcodeValue,
        if (barcodeFormat != null) 'barcode_format': barcodeFormat,
        'scanned_at': scannedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
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
      );
}
