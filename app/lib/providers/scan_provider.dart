import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../data/api/scans_api.dart';
import '../data/local/local_scan.dart';
import 'task_provider.dart';

const _uuid = Uuid();

class ScanNotifier extends StateNotifier<List<LocalScan>> {
  ScanNotifier(this._ref) : super([]);

  final Ref _ref;
  final _api = ScansApi();

  String? _lastValue;
  DateTime? _lastAt;

  /// Fetch synced scans from server (used by web to see mobile scans)
  Future<void> fetchFromServer({String? tenantId, String? projectId}) async {
    try {
      final response = await _api.list(
        tenantId: tenantId,
        projectId: projectId,
        perPage: 200,
      );
      final items = (response['data'] as List?) ?? [];
      final serverScans = items.map<LocalScan>((item) {
        final m = item as Map<String, dynamic>;
        final metadata = m['metadata'] as Map<String, dynamic>? ?? const {};
        return LocalScan(
          id: m['id']?.toString() ?? '',
          projectId: m['project_id']?.toString() ?? '',
          barcodeValue: m['barcode_value']?.toString() ?? '',
          barcodeFormat: m['barcode_format']?.toString(),
          scannedAt: DateTime.tryParse(m['scanned_at']?.toString() ?? '') ??
              DateTime.now(),
          notes: m['notes']?.toString() ?? m['project_name']?.toString(),
          username: m['username']?.toString(),
          synced: true,
          sendId: metadata['send_id']?.toString(),
          batchName: metadata['batch_name']?.toString(),
          sourceFile: metadata['source_file']?.toString(),
          kind: m['kind']?.toString(),
        );
      }).toList();

      if (tenantId != null) {
        state = serverScans;
      } else {
        // Merge: keep local pending scans + replace synced with server data
        final pending = state.where((s) => !s.synced).toList();
        state = [...pending, ...serverScans];
      }
    } catch (_) {
      // Server unavailable — keep local state
    }
  }

  bool shouldAccept(String value) {
    final now = DateTime.now();
    if (_lastValue == value && _lastAt != null) {
      final diff = now.difference(_lastAt!).inMilliseconds;
      if (diff < AppConstants.duplicateCooldownMs) return false;
    }
    _lastValue = value;
    _lastAt = now;
    return true;
  }

  /// Adds a scan locally. Returns `true` if the scan was actually added,
  /// `false` if it was deduped because an identical row already exists.
  ///
  /// Kinds [ScanKind.epcRead] and [ScanKind.packingList] are deduped per
  /// task by case-insensitive `barcodeValue` so the C5 reader can pass over
  /// the same tag twice and the receiving Excel can be re-imported without
  /// creating duplicate rows. The server enforces the same rule at the DB
  /// level via the partial UNIQUE indexes from migration 007.
  bool addScan({
    required String taskId,
    required String taskName,
    required String barcodeValue,
    String? barcodeFormat,
    String? username,
    String? batchName,
    String? sourceFile,
    String? kind,
    String? notes,
  }) {
    final normalizedKind = ScanKind.normalize(kind);
    final isDeduped = normalizedKind == ScanKind.epcRead ||
        normalizedKind == ScanKind.packingList;

    if (isDeduped) {
      final upper = barcodeValue.toUpperCase();
      final exists = state.any(
        (s) =>
            s.projectId == taskId &&
            s.kind == normalizedKind &&
            s.barcodeValue.toUpperCase() == upper,
      );
      if (exists) return false;
    }

    final scan = LocalScan(
      id: _uuid.v4(),
      projectId: taskId,
      barcodeValue: barcodeValue,
      barcodeFormat: barcodeFormat,
      scannedAt: DateTime.now(),
      notes: notes ?? taskName,
      username: username,
      batchName: batchName,
      sourceFile: sourceFile,
      kind: normalizedKind,
    );
    state = [scan, ...state];
    return true;
  }

  void updateBarcode(String id, String newValue) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(barcodeValue: newValue) else s,
    ];
  }

  void removeScan(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  /// Deletes every scan of [kind] in [taskId] from both server and local
  /// state. Used by "Clear packing list" / "Clear all EPC reads" buttons in
  /// the receiving tab.
  ///
  /// Only `epc_read` and `packing_list` kinds are accepted (the server
  /// rejects everything else with 400).
  Future<int> bulkDeleteByKind({
    required String taskId,
    required String kind,
  }) async {
    final normalized = ScanKind.normalize(kind);
    if (normalized != ScanKind.epcRead &&
        normalized != ScanKind.packingList) {
      throw ArgumentError('bulkDeleteByKind only supports epc_read / packing_list');
    }
    final deleted = await _api.bulkDelete(projectId: taskId, kind: normalized);
    state = state
        .where((s) => !(s.projectId == taskId && s.kind == normalized))
        .toList();
    return deleted;
  }

  /// Deletes a specific subset of `kind` rows in [taskId] (matched by
  /// case-insensitive barcode value). Used by "Remove orphans" in the
  /// receiving summary view to drop EPCs that don't appear on the packing
  /// list.
  Future<int> bulkDeleteValues({
    required String taskId,
    required String kind,
    required List<String> values,
  }) async {
    if (values.isEmpty) return 0;
    final normalized = ScanKind.normalize(kind);
    final deleted = await _api.bulkDelete(
      projectId: taskId,
      kind: normalized,
      values: values,
    );
    final upperSet = values.map((v) => v.toUpperCase()).toSet();
    state = state
        .where(
          (s) => !(s.projectId == taskId &&
              s.kind == normalized &&
              upperSet.contains(s.barcodeValue.toUpperCase())),
        )
        .toList();
    return deleted;
  }

  List<LocalScan> get pending => state.where((s) => !s.synced).toList();
  List<LocalScan> get synced => state.where((s) => s.synced).toList();

  List<LocalScan> scansForTask(String taskId) =>
      state.where((s) => s.projectId == taskId).toList();

  Future<({int sent, int failed})> syncPending() async {
    final toSync = pending;
    if (toSync.isEmpty) return (sent: 0, failed: 0);

    // Step 1: promote any local-only tasks to the server first, so every scan
    // carries a real UUID project_id by the time we POST /scans/batch.
    final localProjectIds = toSync
        .map((s) => s.projectId)
        .toSet()
        .where((id) => !isServerTaskId(id))
        .toList();

    final projectIdMap = <String, String>{};
    final taskSyncErrors = <String, String>{};

    if (localProjectIds.isNotEmpty) {
      final tasks = _ref.read(tasksProvider.notifier);
      for (final localId in localProjectIds) {
        try {
          final serverId = await tasks.ensureSyncedToServer(localId);
          projectIdMap[localId] = serverId;
        } catch (e) {
          debugPrint('[ScanNotifier] Task promotion failed for $localId: $e');
          taskSyncErrors[localId] = e.toString();
        }
      }
    }

    // Reflect remapped project_ids in the in-memory scan list so later loads
    // stay consistent with the server.
    if (projectIdMap.isNotEmpty) {
      state = [
        for (final scan in state)
          if (projectIdMap.containsKey(scan.projectId))
            scan.copyWith(projectId: projectIdMap[scan.projectId])
          else
            scan,
      ];
    }

    // Step 2: separate scans whose task could not be promoted — mark them
    // failed and skip them from this sync pass.
    final syncableSource = <LocalScan>[];
    final skippedIds = <String>{};
    for (final scan in pending) {
      if (taskSyncErrors.containsKey(scan.projectId)) {
        skippedIds.add(scan.id);
        continue;
      }
      syncableSource.add(scan);
    }

    if (skippedIds.isNotEmpty) {
      state = [
        for (final s in state)
          if (skippedIds.contains(s.id))
            s.copyWith(
              synced: false,
              error:
                  'Энэ scan-ы даалгаврыг серверт үүсгэж чадсангүй. Интернэт/нэвтрэлтээ шалгаад дахин оролдоно уу.',
            )
          else
            s,
      ];
    }

    if (syncableSource.isEmpty) {
      return (sent: 0, failed: skippedIds.length);
    }

    final sendId = _createSendId();
    final toSyncWithId = [
      for (final scan in syncableSource)
        scan.copyWith(sendId: sendId, clearError: true),
    ];

    state = [
      for (final scan in state)
        if (toSyncWithId.any((updated) => updated.id == scan.id))
          toSyncWithId.firstWhere((updated) => updated.id == scan.id)
        else
          scan,
    ];

    try {
      final response =
          await _api.batchSync(toSyncWithId.map((s) => s.toApiJson()).toList());
      final syncedCount = response['count'] as int? ?? 0;
      if (syncedCount != toSyncWithId.length) {
        throw Exception(
            'Batch sync incomplete: expected ${toSyncWithId.length}, got $syncedCount');
      }
    } catch (e) {
      final message = 'Sync failed: $e';
      state = [
        for (final s in state)
          if (toSyncWithId.any((p) => p.id == s.id))
            s.copyWith(synced: false, error: message)
          else
            s,
      ];
      return (sent: 0, failed: toSyncWithId.length + skippedIds.length);
    }

    state = [
      for (final s in state)
        if (toSyncWithId.any((p) => p.id == s.id))
          s.copyWith(synced: true, clearError: true)
        else
          s,
    ];

    return (sent: toSyncWithId.length, failed: skippedIds.length);
  }

  void clearSynced() {
    state = state.where((s) => !s.synced).toList();
  }

  String _createSendId() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final suffix = _uuid.v4().split('-').first.toUpperCase();
    return 'SEND-$stamp-$suffix';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, List<LocalScan>>((ref) {
  return ScanNotifier(ref);
});
