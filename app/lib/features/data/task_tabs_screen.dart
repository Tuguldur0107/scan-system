import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/epc_converter.dart';
import '../../data/local/local_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/ui_state_widgets.dart';

/// Four-tab task workspace.
///
/// Tab 1 — "Скан + гар оруулах": barcodes captured by camera or typed by hand
///         on the mobile device.
/// Tab 2 — "Barcode → EPC":      packing-list rows imported from Excel/CSV
///         on web and converted to SGTIN-96 EPCs.
/// Tab 3 — "EPC → Barcode":      UHF tags read by the C5 hand reader, with
///         the EPC decoded back to its underlying GTIN.
/// Tab 4 — "Хүлээж авах":         supplier packing list (barcode + qty)
///         reconciled against the C5 EPC reads from tab 3. Matched / pending /
///         over / orphan items + bulk-remove orphans are all here.
///
/// Each tab filters the scan list by `LocalScan.kind` and renders its own
/// columns; tabs 1-3 don't cross over, and tab 4 only *reads* tab 3's data
/// for matching — nothing in this screen mutates it.
class TaskTabsScreen extends ConsumerStatefulWidget {
  const TaskTabsScreen({super.key, this.initialSendId, this.initialTab = 0});

  final String? initialSendId;
  final int initialTab;

  @override
  ConsumerState<TaskTabsScreen> createState() => _TaskTabsScreenState();
}

class _TaskTabsScreenState extends ConsumerState<TaskTabsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _refreshFromServer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshFromServer() async {
    setState(() => _loading = true);
    final selectedTask = ref.read(selectedTaskProvider);
    await ref
        .read(scanProvider.notifier)
        .fetchFromServer(projectId: selectedTask?.id);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTask = ref.watch(selectedTaskProvider);
    final allScans = ref.watch(scanProvider);
    final scans = selectedTask != null
        ? allScans.where((s) => s.projectId == selectedTask.id).toList()
        : <LocalScan>[];

    final scanRows = scans
        .where((s) => s.kind == ScanKind.barcodeScan)
        .toList(growable: false);
    final epcImportRows =
        scans.where((s) => s.kind == ScanKind.epcImport).toList(growable: false);
    final epcReadRows =
        scans.where((s) => s.kind == ScanKind.epcRead).toList(growable: false);
    final packingListRows = scans
        .where((s) => s.kind == ScanKind.packingList)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tasks'),
        ),
        title: Text(selectedTask?.name ?? 'Бүх дата'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Серверээс шинэчлэх',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshFromServer,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.qr_code_scanner),
              text: 'Скан + гар (${scanRows.length})',
            ),
            Tab(
              icon: const Icon(Icons.upload_file),
              text: 'Barcode → EPC (${epcImportRows.length})',
            ),
            Tab(
              icon: const Icon(Icons.nfc),
              text: 'EPC → Barcode (${epcReadRows.length})',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: 'Хүлээж авах (${packingListRows.length})',
            ),
          ],
        ),
      ),
      body: selectedTask == null
          ? const AppEmptyView(
              icon: Icons.task_alt,
              title: 'Task сонгоогүй байна',
              message: 'Эхлээд /tasks хэсгээс task сонгоно уу.',
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _BarcodeScanTab(rows: scanRows),
                _EpcImportTab(rows: epcImportRows),
                _EpcReadTab(rows: epcReadRows),
                _ReceivingTab(
                  packingRows: packingListRows,
                  epcReadRows: epcReadRows,
                  taskId: selectedTask.id,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — Scan + manual entry
// ---------------------------------------------------------------------------
class _BarcodeScanTab extends ConsumerWidget {
  const _BarcodeScanTab({required this.rows});

  final List<LocalScan> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScaffold(
      header: _TabHeader(
        title: 'Скан + гар оруулах',
        subtitle:
            'Камерын scan, мөн танигдаагүй баркодыг гараар бичих горим. '
            'Энэ хүснэгт нь зөвхөн mobile болон гар оруулгаас орсон мөрүүдийг харуулна.',
        primaryAction: kIsWeb
            ? null
            : _PrimaryAction(
                icon: Icons.qr_code_scanner,
                label: 'Шинэ scan хийх',
                onPressed: () => context.go('/scan'),
              ),
        secondaryAction: _SecondaryAction(
          icon: Icons.edit,
          label: 'Гараар нэмэх',
          onPressed: kIsWeb
              ? null
              : () => _openManualEntry(context, ref),
          disabledReason: kIsWeb ? 'Зөвхөн mobile дээр' : null,
        ),
      ),
      empty: rows.isEmpty
          ? const AppEmptyView(
              icon: Icons.qr_code,
              title: 'Скан мэдээлэл алга',
              message:
                  'Scan хийх эсвэл гараар баркод оруулсаны дараа энд харагдана.',
            )
          : null,
      table: rows.isEmpty
          ? null
          : _DataTable(
              rows: rows,
              columns: const [
                _ColumnSpec(label: '#'),
                _ColumnSpec(label: 'Илгээсэн ID'),
                _ColumnSpec(label: 'Баркод', monospace: true),
                _ColumnSpec(label: 'Формат'),
                _ColumnSpec(label: 'Огноо'),
                _ColumnSpec(label: 'Цаг'),
                _ColumnSpec(label: 'Хэрэглэгч'),
                _ColumnSpec(label: 'Төлөв', isStatus: true),
              ],
              valuesBuilder: (scan, index) => [
                '${index + 1}',
                scan.sendId ?? '-',
                scan.barcodeValue,
                scan.barcodeFormat ?? '-',
                _formatDate(scan.scannedAt),
                _formatTime(scan.scannedAt),
                scan.username ?? '-',
                scan.synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
              ],
            ),
    );
  }

  Future<void> _openManualEntry(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final selectedTask = ref.read(selectedTaskProvider);
    if (selectedTask == null) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Гараар баркод нэмэх'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Баркод',
              hintText: 'Жишээ: 8888888000003',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Хадгалах'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    final auth = ref.read(authStateProvider);
    ref.read(scanProvider.notifier).addScan(
          taskId: selectedTask.id,
          taskName: selectedTask.name,
          barcodeValue: result,
          username: auth.user?['username'] as String?,
          kind: ScanKind.barcodeScan,
        );
    ref.read(tasksProvider.notifier).incrementScanCount(selectedTask.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нэмэгдсэн: $result')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Barcode → EPC import (web only entry point)
// ---------------------------------------------------------------------------
class _EpcImportTab extends ConsumerWidget {
  const _EpcImportTab({required this.rows});

  final List<LocalScan> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScaffold(
      header: _TabHeader(
        title: 'Barcode → EPC',
        subtitle:
            'Excel/CSV packing list-ээ оруулж SGTIN-96 EPC болгож хөрвүүлнэ. '
            'Серийн дугаар нь tenant дээр давтагдахгүйгээр дарааллана.',
        primaryAction: kIsWeb
            ? _PrimaryAction(
                icon: Icons.upload_file,
                label: 'Excel оруулах',
                onPressed: () => context.go('/import/barcode-epc'),
              )
            : null,
        secondaryAction: kIsWeb
            ? null
            : const _SecondaryAction(
                icon: Icons.upload_file,
                label: 'Excel оруулах',
                onPressed: null,
                disabledReason: 'Зөвхөн web-ээс файл оруулна',
              ),
      ),
      empty: rows.isEmpty
          ? const AppEmptyView(
              icon: Icons.upload_file,
              title: 'Импорт хийгдээгүй байна',
              message:
                  'Web-ээс packing list-ээ оруулмагц энд GTIN-14 + EPC-үүд харагдана.',
            )
          : null,
      table: rows.isEmpty
          ? null
          : _DataTable(
              rows: rows,
              columns: const [
                _ColumnSpec(label: '#'),
                _ColumnSpec(label: 'Илгээсэн ID'),
                _ColumnSpec(label: 'GTIN-14', monospace: true),
                _ColumnSpec(label: 'EPC', monospace: true),
                _ColumnSpec(label: 'Серийн №'),
                _ColumnSpec(label: 'Файл'),
                _ColumnSpec(label: 'Огноо'),
                _ColumnSpec(label: 'Хэрэглэгч'),
                _ColumnSpec(label: 'Төлөв', isStatus: true),
              ],
              valuesBuilder: (scan, index) {
                final parsed = _parseEpcImportNotes(scan.notes);
                return [
                  '${index + 1}',
                  scan.sendId ?? '-',
                  parsed.gtin14 ??
                      EpcConverter.tryConvertToBarcode(scan.barcodeValue)
                              ?.value ??
                          '-',
                  scan.barcodeValue,
                  parsed.serial ?? '-',
                  scan.sourceFile ?? '-',
                  _formatDate(scan.scannedAt),
                  scan.username ?? '-',
                  scan.synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
                ];
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — EPC → Barcode (read by C5)
// ---------------------------------------------------------------------------
class _EpcReadTab extends ConsumerWidget {
  const _EpcReadTab({required this.rows});

  final List<LocalScan> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabScaffold(
      header: _TabHeader(
        title: 'EPC → Barcode',
        subtitle:
            'C5 уншигчаар уншсан UHF RFID EPC код. Танигдсан тохиолдолд '
            'GTIN-14 баркод болгож буцаан хөрвүүлж харуулна.',
        primaryAction: kIsWeb
            ? null
            : _PrimaryAction(
                icon: Icons.nfc,
                label: 'C5 reader нээх',
                onPressed: () => context.go('/uhf'),
              ),
        secondaryAction: kIsWeb
            ? const _SecondaryAction(
                icon: Icons.nfc,
                label: 'C5 reader',
                onPressed: null,
                disabledReason:
                    'Web дээр зөвхөн харах. C5-аар уншихад mobile хэрэгтэй',
              )
            : _SecondaryAction(
                icon: Icons.upload_file,
                label: 'EPC файл оруулах',
                onPressed: () => context.go('/convert'),
              ),
      ),
      empty: rows.isEmpty
          ? const AppEmptyView(
              icon: Icons.nfc,
              title: 'C5-аас өгөгдөл алга',
              message:
                  'C5 уншигчаар тэмдэгүүд уншсаны дараа EPC болон decoded barcode энд харагдана.',
            )
          : null,
      table: rows.isEmpty
          ? null
          : _DataTable(
              rows: rows,
              columns: const [
                _ColumnSpec(label: '#'),
                _ColumnSpec(label: 'Илгээсэн ID'),
                _ColumnSpec(label: 'EPC / утга', monospace: true),
                _ColumnSpec(label: 'Decoded barcode', monospace: true),
                _ColumnSpec(label: 'Формат'),
                _ColumnSpec(label: 'Огноо'),
                _ColumnSpec(label: 'Хэрэглэгч'),
                _ColumnSpec(label: 'Төлөв', isStatus: true),
              ],
              valuesBuilder: (scan, index) {
                final decoded = _decodeBarcodeFromScan(scan);
                return [
                  '${index + 1}',
                  scan.sendId ?? '-',
                  scan.barcodeValue,
                  decoded,
                  scan.barcodeFormat ?? 'EPC',
                  _formatDate(scan.scannedAt),
                  scan.username ?? '-',
                  scan.synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
                ];
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4 — Receiving (Хүлээж авах)
// ---------------------------------------------------------------------------

/// Status of a packing-list row after reconciliation against `epc_read` reads.
enum _MatchStatus {
  /// `received >= expected` and `received == expected`.
  matched,

  /// `received < expected` — operator hasn't passed the C5 over enough tags
  /// yet. Expected qty stays in the running total.
  pending,

  /// `received > expected` — supplier shipped too many of this barcode, or
  /// the operator scanned items that aren't from this shipment but happen
  /// to be the same SKU.
  over,
}

class _PackingMatchRow {
  _PackingMatchRow({
    required this.expected,
    required this.received,
    required this.itemCode,
    required this.name,
    required this.carton,
    required this.matchedReadIds,
  });

  final LocalScan expected;
  final int received;
  final String? itemCode;
  final String? name;
  final String? carton;

  /// Local-scan IDs of the EPC reads that decoded to this barcode. Used to
  /// drill-down into the actual EPCs behind a packing-list row.
  final List<String> matchedReadIds;

  int get expectedQty {
    final meta = expected.notes ?? '';
    final m = RegExp(r'qty:\s*(\d+)').firstMatch(meta);
    if (m != null) return int.tryParse(m.group(1)!) ?? 1;
    return 1;
  }

  _MatchStatus get status {
    if (received == 0) return _MatchStatus.pending;
    if (received < expectedQty) return _MatchStatus.pending;
    if (received > expectedQty) return _MatchStatus.over;
    return _MatchStatus.matched;
  }
}

class _ReceivingTab extends ConsumerStatefulWidget {
  const _ReceivingTab({
    required this.packingRows,
    required this.epcReadRows,
    required this.taskId,
  });

  final List<LocalScan> packingRows;
  final List<LocalScan> epcReadRows;
  final String taskId;

  @override
  ConsumerState<_ReceivingTab> createState() => _ReceivingTabState();
}

class _ReceivingTabState extends ConsumerState<_ReceivingTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // Step 1: bucket every epc_read by its decoded GTIN-14 (or the legacy
    // already-decoded barcode value). Reads we can't decode get bucketed
    // under "__undecoded__" so they show up as orphans rather than silently
    // matching nothing.
    final readsByBarcode = <String, List<LocalScan>>{};
    for (final s in widget.epcReadRows) {
      final decoded = _normalizeForMatch(_decodeBarcodeFromScan(s));
      final key = decoded ?? '__undecoded__';
      readsByBarcode.putIfAbsent(key, () => []).add(s);
    }

    // Step 2: walk the packing list and pair each row with the reads we've
    // bucketed for its barcode.
    final matchRows = <_PackingMatchRow>[];
    final matchedKeys = <String>{};
    for (final p in widget.packingRows) {
      final key = _normalizeForMatch(p.barcodeValue);
      final reads = key == null ? const <LocalScan>[] : (readsByBarcode[key] ?? const []);
      if (key != null) matchedKeys.add(key);
      final parsed = _parsePackingNotes(p.notes);
      matchRows.add(_PackingMatchRow(
        expected: p,
        received: reads.length,
        itemCode: parsed.itemCode,
        name: parsed.name,
        carton: parsed.carton,
        matchedReadIds: reads.map((e) => e.id).toList(),
      ));
    }

    // Step 3: anything in `readsByBarcode` whose key didn't pair with a
    // packing-list row is an orphan. Reads we couldn't decode at all are
    // also orphans (the operator's options are: re-scan, drop, or fix the
    // EPC encoding).
    final orphanReads = <LocalScan>[];
    for (final entry in readsByBarcode.entries) {
      if (!matchedKeys.contains(entry.key)) {
        orphanReads.addAll(entry.value);
      }
    }

    final totalExpected =
        matchRows.fold<int>(0, (a, r) => a + r.expectedQty);
    final totalMatched = matchRows.fold<int>(
      0,
      (a, r) =>
          a + (r.received > r.expectedQty ? r.expectedQty : r.received),
    );
    final totalPending = totalExpected - totalMatched;
    final totalOver = matchRows.fold<int>(
      0,
      (a, r) => a + (r.received > r.expectedQty ? r.received - r.expectedQty : 0),
    );
    final totalOrphan = orphanReads.length;

    return _TabScaffold(
      header: _TabHeader(
        title: 'Хүлээж авах (Receiving)',
        subtitle:
            'Ханган нийлүүлэгчээс ирсэн packing list-ийг C5-аар уншсан '
            'EPC-үүдтэй тулгана. Ижил EPC-ийг дахин уншвал давхардуулахгүй, '
            'packing list дээр байхгүй уншигдсан зүйлсийг "орхигдсон" '
            'гэж үзээд бөөнөөр устгах боломжтой.',
        primaryAction: kIsWeb
            ? _PrimaryAction(
                icon: Icons.upload_file,
                label: 'Packing list оруулах',
                onPressed: () => context.go('/import/packing-list'),
              )
            : null,
        secondaryAction: kIsWeb
            ? null
            : const _SecondaryAction(
                icon: Icons.upload_file,
                label: 'Packing list оруулах',
                onPressed: null,
                disabledReason: 'Зөвхөн web-ээс файл оруулна',
              ),
      ),
      empty: widget.packingRows.isEmpty && widget.epcReadRows.isEmpty
          ? const AppEmptyView(
              icon: Icons.inventory_2_outlined,
              title: 'Packing list болон уншилт алга',
              message:
                  'Ханган нийлүүлэгчийн packing list-ийг web-ээс оруулсаны дараа '
                  'C5 уншигчаар тэмдгүүдийг уншиж тулгана.',
            )
          : null,
      table: widget.packingRows.isEmpty && widget.epcReadRows.isEmpty
          ? null
          : _ReceivingBody(
              matchRows: matchRows,
              orphanReads: orphanReads,
              totalExpected: totalExpected,
              totalMatched: totalMatched,
              totalPending: totalPending,
              totalOver: totalOver,
              totalOrphan: totalOrphan,
              busy: _busy,
              onClearPacking: widget.packingRows.isEmpty
                  ? null
                  : _confirmClearPacking,
              onRemoveOrphans: orphanReads.isEmpty ? null : _confirmRemoveOrphans,
            ),
    );
  }

  Future<void> _confirmClearPacking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Packing list-г бүхэлд нь устгах уу?'),
        content: const Text(
          'Энэ task-ийн бүх packing list мөрүүд устах болно. '
          'C5-аар уншсан EPC-үүд хэвээр үлдэнэ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(scanProvider.notifier).bulkDeleteByKind(
            taskId: widget.taskId,
            kind: ScanKind.packingList,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n packing list мөр устгалаа')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Устгах алдаа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemoveOrphans() async {
    final orphanCount = widget.epcReadRows
        .where((s) {
          final decoded = _normalizeForMatch(_decodeBarcodeFromScan(s));
          if (decoded == null) return true;
          return widget.packingRows.every(
            (p) => _normalizeForMatch(p.barcodeValue) != decoded,
          );
        })
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Орхигдсон уншилтуудыг устгах уу?'),
        content: Text(
          'Packing list дээр байхгүй $orphanCount EPC уншилт устах болно. '
          'Packing list мөрүүдтэй таарсан уншилтууд хэвээр үлдэнэ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final orphanValues = <String>[];
    for (final s in widget.epcReadRows) {
      final decoded = _normalizeForMatch(_decodeBarcodeFromScan(s));
      if (decoded == null) {
        orphanValues.add(s.barcodeValue);
      } else if (widget.packingRows.every(
        (p) => _normalizeForMatch(p.barcodeValue) != decoded,
      )) {
        orphanValues.add(s.barcodeValue);
      }
    }
    if (orphanValues.isEmpty) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(scanProvider.notifier).bulkDeleteValues(
            taskId: widget.taskId,
            kind: ScanKind.epcRead,
            values: orphanValues,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n орхигдсон уншилт устгалаа')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Устгах алдаа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ReceivingBody extends StatelessWidget {
  const _ReceivingBody({
    required this.matchRows,
    required this.orphanReads,
    required this.totalExpected,
    required this.totalMatched,
    required this.totalPending,
    required this.totalOver,
    required this.totalOrphan,
    required this.busy,
    required this.onClearPacking,
    required this.onRemoveOrphans,
  });

  final List<_PackingMatchRow> matchRows;
  final List<LocalScan> orphanReads;
  final int totalExpected;
  final int totalMatched;
  final int totalPending;
  final int totalOver;
  final int totalOrphan;
  final bool busy;
  final VoidCallback? onClearPacking;
  final VoidCallback? onRemoveOrphans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCards(
          totalExpected: totalExpected,
          totalMatched: totalMatched,
          totalPending: totalPending,
          totalOver: totalOver,
          totalOrphan: totalOrphan,
        ),
        const SizedBox(height: 12),
        _PackingMatchTable(rows: matchRows, busy: busy, onClear: onClearPacking),
        if (orphanReads.isNotEmpty) ...[
          const SizedBox(height: 12),
          _OrphanReadsCard(
            orphans: orphanReads,
            busy: busy,
            onRemoveAll: onRemoveOrphans,
          ),
        ],
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.totalExpected,
    required this.totalMatched,
    required this.totalPending,
    required this.totalOver,
    required this.totalOrphan,
  });

  final int totalExpected;
  final int totalMatched;
  final int totalPending;
  final int totalOver;
  final int totalOrphan;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: 'Хүлээгдэж буй',
          value: totalExpected,
          color: const Color(0xFF455A64),
        ),
        _StatCard(
          label: 'Тулгасан',
          value: totalMatched,
          color: const Color(0xFF0F8B68),
        ),
        _StatCard(
          label: 'Дутуу',
          value: totalPending,
          color: const Color(0xFFB58E00),
        ),
        _StatCard(
          label: 'Илүү',
          value: totalOver,
          color: const Color(0xFFB84C4C),
        ),
        _StatCard(
          label: 'Орхигдсон',
          value: totalOrphan,
          color: const Color(0xFFB84C4C),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackingMatchTable extends StatelessWidget {
  const _PackingMatchTable({
    required this.rows,
    required this.busy,
    required this.onClear,
  });

  final List<_PackingMatchRow> rows;
  final bool busy;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Packing list — ${rows.length} мөр',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onClear != null)
                  TextButton.icon(
                    onPressed: busy ? null : onClear,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Packing list устгах'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Packing list оруулаагүй байна. Web-ээс Excel/CSV оруулна уу.',
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Barcode')),
                  DataColumn(label: Text('Item code')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Carton')),
                  DataColumn(label: Text('Хүлээгдэж')),
                  DataColumn(label: Text('Уншсан')),
                  DataColumn(label: Text('Зөрөө')),
                  DataColumn(label: Text('Төлөв')),
                ],
                rows: [
                  for (var i = 0; i < rows.length; i++)
                    DataRow(
                      color: WidgetStateProperty.resolveWith((_) {
                        switch (rows[i].status) {
                          case _MatchStatus.matched:
                            return Colors.green.withValues(alpha: 0.06);
                          case _MatchStatus.pending:
                            return Colors.orange.withValues(alpha: 0.06);
                          case _MatchStatus.over:
                            return Colors.red.withValues(alpha: 0.06);
                        }
                      }),
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(SelectableText(
                          rows[i].expected.barcodeValue,
                          style: const TextStyle(fontFamily: 'monospace'),
                        )),
                        DataCell(Text(rows[i].itemCode ?? '-')),
                        DataCell(Text(rows[i].name ?? '-')),
                        DataCell(Text(rows[i].carton ?? '-')),
                        DataCell(Text('${rows[i].expectedQty}')),
                        DataCell(Text('${rows[i].received}')),
                        DataCell(Text(
                          '${rows[i].received - rows[i].expectedQty}',
                        )),
                        DataCell(_StatusChip(status: rows[i].status)),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      _MatchStatus.matched => (const Color(0xFF0F8B68), 'Тулгасан'),
      _MatchStatus.pending => (const Color(0xFFB58E00), 'Дутуу'),
      _MatchStatus.over => (const Color(0xFFB84C4C), 'Илүү'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OrphanReadsCard extends StatelessWidget {
  const _OrphanReadsCard({
    required this.orphans,
    required this.busy,
    required this.onRemoveAll,
  });

  final List<LocalScan> orphans;
  final bool busy;
  final VoidCallback? onRemoveAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Орхигдсон уншилтууд — ${orphans.length} мөр',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onRemoveAll,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Бүгдийг устгах'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('EPC')),
                DataColumn(label: Text('Decoded barcode')),
                DataColumn(label: Text('Огноо')),
                DataColumn(label: Text('Хэрэглэгч')),
              ],
              rows: [
                for (var i = 0; i < orphans.length; i++)
                  DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(SelectableText(
                      orphans[i].barcodeValue,
                      style: const TextStyle(fontFamily: 'monospace'),
                    )),
                    DataCell(Text(_decodeBarcodeFromScan(orphans[i]))),
                    DataCell(Text(_formatDate(orphans[i].scannedAt))),
                    DataCell(Text(orphans[i].username ?? '-')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedPackingNotes {
  const _ParsedPackingNotes({this.itemCode, this.name, this.carton});
  final String? itemCode;
  final String? name;
  final String? carton;
}

/// Parses the structured `notes` written by `WebPackingListImportScreen`:
/// `qty: 6 | item: 701236091-009-M | name: Levi 501 | carton: BX-12`.
_ParsedPackingNotes _parsePackingNotes(String? notes) {
  if (notes == null) return const _ParsedPackingNotes();
  String? itemCode;
  String? name;
  String? carton;
  for (final part in notes.split('|')) {
    final p = part.trim();
    if (p.startsWith('item:')) {
      itemCode = p.substring('item:'.length).trim();
    } else if (p.startsWith('name:')) {
      name = p.substring('name:'.length).trim();
    } else if (p.startsWith('carton:')) {
      carton = p.substring('carton:'.length).trim();
    }
  }
  return _ParsedPackingNotes(itemCode: itemCode, name: name, carton: carton);
}

/// Normalizes a raw barcode (12-14 digits) or already-decoded GTIN-14 to a
/// common 14-digit form so packing-list rows and EPC-decoded reads collide
/// on the same key. Returns null if the value isn't a recognizable GTIN
/// (e.g. an undecoded EPC error message).
String? _normalizeForMatch(String? raw) {
  if (raw == null) return null;
  final r = raw.trim();
  if (r.isEmpty) return null;
  return EpcConverter.normalizeToGtin14(r);
}

// ---------------------------------------------------------------------------
// Shared layout building blocks
// ---------------------------------------------------------------------------
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({required this.header, this.empty, this.table});

  final Widget header;
  final Widget? empty;
  final Widget? table;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        header,
        const SizedBox(height: 16),
        if (empty != null) empty!,
        if (table != null) table!,
      ],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({
    required this.title,
    required this.subtitle,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String subtitle;
  final _PrimaryAction? primaryAction;
  final _SecondaryAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          if (primaryAction != null || secondaryAction != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (primaryAction != null)
                  FilledButton.icon(
                    onPressed: primaryAction!.onPressed,
                    icon: Icon(primaryAction!.icon),
                    label: Text(primaryAction!.label),
                  ),
                if (secondaryAction != null)
                  Tooltip(
                    message: secondaryAction!.disabledReason ?? '',
                    child: OutlinedButton.icon(
                      onPressed: secondaryAction!.onPressed,
                      icon: Icon(secondaryAction!.icon),
                      label: Text(secondaryAction!.label),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryAction {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _SecondaryAction {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;
}

// ---------------------------------------------------------------------------
// Generic table
// ---------------------------------------------------------------------------
class _ColumnSpec {
  const _ColumnSpec({
    required this.label,
    this.monospace = false,
    this.isStatus = false,
  });

  final String label;
  final bool monospace;
  final bool isStatus;
}

typedef _RowValuesBuilder = List<String> Function(LocalScan scan, int index);

class _DataTable extends StatelessWidget {
  const _DataTable({
    required this.rows,
    required this.columns,
    required this.valuesBuilder,
  });

  final List<LocalScan> rows;
  final List<_ColumnSpec> columns;
  final _RowValuesBuilder valuesBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${rows.length} мөр',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Хуулах (TSV)',
                  icon: const Icon(Icons.copy_all),
                  onPressed: () => _copyTsv(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final c in columns) DataColumn(label: Text(c.label)),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    cells: _buildCells(context, rows[i], i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DataCell> _buildCells(BuildContext context, LocalScan scan, int index) {
    final values = valuesBuilder(scan, index);
    return [
      for (var c = 0; c < columns.length; c++)
        DataCell(_cellForColumn(context, columns[c], values[c], scan)),
    ];
  }

  Widget _cellForColumn(
    BuildContext context,
    _ColumnSpec spec,
    String value,
    LocalScan scan,
  ) {
    if (spec.isStatus) {
      return _StatusBadge(synced: scan.synced);
    }
    return Text(
      value,
      style: spec.monospace
          ? const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)
          : null,
    );
  }

  Future<void> _copyTsv(BuildContext context) async {
    final lines = <String>[];
    lines.add(columns.map((c) => c.label).join('\t'));
    for (var i = 0; i < rows.length; i++) {
      lines.add(valuesBuilder(rows[i], i).join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} мөр clipboard руу хуулагдлаа')),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    final color = synced ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        synced ? 'Синк хийсэн' : 'Хүлээгдэж буй',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
class _ParsedEpcImportNotes {
  const _ParsedEpcImportNotes({this.gtin14, this.serial, this.tenantTotal});

  final String? gtin14;
  final String? serial;
  final String? tenantTotal;
}

/// Parses the structured `notes` written by `WebBarcodeEpcImportScreen`:
/// `GTIN-14: 08888888000003 | raw: 8888888000003 | serial: 1 | tenant total: 5`.
/// Returns empty fields if the format is not recognised (e.g. legacy rows).
_ParsedEpcImportNotes _parseEpcImportNotes(String? notes) {
  if (notes == null) return const _ParsedEpcImportNotes();
  String? gtin14;
  String? serial;
  String? total;
  for (final part in notes.split('|')) {
    final p = part.trim();
    if (p.startsWith('GTIN-14:')) {
      gtin14 = p.substring('GTIN-14:'.length).trim();
    } else if (p.startsWith('serial:')) {
      serial = p.substring('serial:'.length).trim();
    } else if (p.startsWith('tenant total:')) {
      total = p.substring('tenant total:'.length).trim();
    }
  }
  return _ParsedEpcImportNotes(
    gtin14: gtin14,
    serial: serial,
    tenantTotal: total,
  );
}

String _decodeBarcodeFromScan(LocalScan scan) {
  // Legacy rows: older builds saved barcode directly when auto-convert was ON.
  // Keep showing that value as decoded barcode for backward compatibility.
  final format = (scan.barcodeFormat ?? '').toUpperCase();
  final raw = scan.barcodeValue.trim().toUpperCase();
  if (format == 'EPC->BARCODE' && RegExp(r'^\d{8,14}$').hasMatch(raw)) {
    return scan.barcodeValue;
  }

  final cleaned = raw.replaceAll(RegExp(r'[^0-9A-F]'), '');

  // 1) Normal direct decode path.
  final direct = EpcConverter.tryConvertToBarcode(cleaned);
  if (direct != null) return direct.value;

  // 2) Some readers prepend 16-bit PC (4 hex chars): [PC][EPC(24)].
  if (cleaned.length >= 28) {
    final tail24 = cleaned.substring(cleaned.length - 24);
    final tail = EpcConverter.tryConvertToBarcode(tail24);
    if (tail != null) return '${tail.value} (PC stripped)';
  }

  // 3) Explain why decode failed.
  if (cleaned.length < 24) return 'Хэт богино EPC (${cleaned.length} hex)';
  final candidate = cleaned.length >= 24 ? cleaned.substring(0, 24) : cleaned;
  final firstByteHex = candidate.substring(0, 2);
  if (firstByteHex != '30') {
    return 'SGTIN-96 биш (header=$firstByteHex)';
  }
  return 'GTIN decode амжилтгүй';
}

String _formatDate(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

String _formatTime(DateTime dt) =>
    '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';

String _two(int v) => v.toString().padLeft(2, '0');
