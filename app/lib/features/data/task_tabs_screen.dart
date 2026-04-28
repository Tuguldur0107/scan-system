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

/// Three-tab task workspace.
///
/// Tab 1 — "Скан + гар оруулах": barcodes captured by camera or typed by hand
///         on the mobile device.
/// Tab 2 — "Barcode → EPC":      packing-list rows imported from Excel/CSV
///         on web and converted to SGTIN-96 EPCs.
/// Tab 3 — "EPC → Barcode":      UHF tags read by the C5 hand reader, with
///         the EPC decoded back to its underlying GTIN.
///
/// Each tab filters the scan list by `LocalScan.kind` and renders its own
/// columns; nothing crosses between tabs even though they all live under
/// the same task.
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
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
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
                  decoded ?? '-',
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

String? _decodeBarcodeFromScan(LocalScan scan) {
  // C5 reads with auto-convert ON already store the decoded GTIN as the
  // barcode_value; in that case the value is already a barcode (not an EPC).
  if ((scan.barcodeFormat ?? '').toUpperCase() == 'EPC->BARCODE') {
    return scan.barcodeValue;
  }
  final res = EpcConverter.tryConvertToBarcode(scan.barcodeValue);
  return res?.value;
}

String _formatDate(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

String _formatTime(DateTime dt) =>
    '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';

String _two(int v) => v.toString().padLeft(2, '0');
