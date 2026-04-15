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

  Map<String, dynamic> toApiJson() => {
        'project_id': projectId,
        'barcode_value': barcodeValue,
        if (barcodeFormat != null) 'barcode_format': barcodeFormat,
        'scanned_at': scannedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
        'metadata': {
          if (sendId != null && sendId!.trim().isNotEmpty) 'send_id': sendId,
        },
      };

  LocalScan copyWith({
    bool? synced,
    String? error,
    String? barcodeValue,
    String? sendId,
    bool clearError = false,
  }) =>
      LocalScan(
        id: id,
        projectId: projectId,
        barcodeValue: barcodeValue ?? this.barcodeValue,
        barcodeFormat: barcodeFormat,
        scannedAt: scannedAt,
        notes: notes,
        username: username,
        synced: synced ?? this.synced,
        error: clearError ? null : (error ?? this.error),
        sendId: sendId ?? this.sendId,
      );
}
