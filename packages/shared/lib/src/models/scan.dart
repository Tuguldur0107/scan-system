import 'package:equatable/equatable.dart';

class Scan extends Equatable {
  const Scan({
    required this.id,
    required this.tenantId,
    required this.projectId,
    required this.userId,
    required this.barcodeValue,
    this.barcodeFormat,
    required this.scannedAt,
    this.syncedAt,
    this.notes,
    this.metadata = const {},
  });

  final String id;
  final String tenantId;
  final String projectId;
  final String userId;
  final String barcodeValue;
  final String? barcodeFormat;
  final DateTime scannedAt;
  final DateTime? syncedAt;
  final String? notes;
  final Map<String, dynamic> metadata;

  factory Scan.fromJson(Map<String, dynamic> json) => Scan(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        projectId: json['project_id'] as String,
        userId: json['user_id'] as String,
        barcodeValue: json['barcode_value'] as String,
        barcodeFormat: json['barcode_format'] as String?,
        scannedAt: DateTime.parse(json['scanned_at'] as String),
        syncedAt: json['synced_at'] != null
            ? DateTime.parse(json['synced_at'] as String)
            : null,
        notes: json['notes'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'project_id': projectId,
        'user_id': userId,
        'barcode_value': barcodeValue,
        if (barcodeFormat != null) 'barcode_format': barcodeFormat,
        'scanned_at': scannedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
        if (notes != null) 'notes': notes,
        'metadata': metadata,
      };

  @override
  List<Object?> get props => [id, tenantId, projectId, barcodeValue, scannedAt];
}

class CreateScanRequest {
  const CreateScanRequest({
    required this.projectId,
    required this.barcodeValue,
    this.barcodeFormat,
    required this.scannedAt,
    this.notes,
    this.metadata = const {},
  });

  final String projectId;
  final String barcodeValue;
  final String? barcodeFormat;
  final DateTime scannedAt;
  final String? notes;
  final Map<String, dynamic> metadata;

  factory CreateScanRequest.fromJson(Map<String, dynamic> json) =>
      CreateScanRequest(
        projectId: json['project_id'] as String,
        barcodeValue: json['barcode_value'] as String,
        barcodeFormat: json['barcode_format'] as String?,
        scannedAt: DateTime.parse(json['scanned_at'] as String),
        notes: json['notes'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'barcode_value': barcodeValue,
        if (barcodeFormat != null) 'barcode_format': barcodeFormat,
        'scanned_at': scannedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
        'metadata': metadata,
      };
}

class BatchScanRequest {
  const BatchScanRequest({required this.scans});

  final List<CreateScanRequest> scans;

  factory BatchScanRequest.fromJson(Map<String, dynamic> json) =>
      BatchScanRequest(
        scans: (json['scans'] as List)
            .map((e) => CreateScanRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'scans': scans.map((s) => s.toJson()).toList(),
      };
}
