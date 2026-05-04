import 'dart:async';
import 'dart:typed_data';

import 'package:excel/excel.dart' show Data;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/scans_api.dart';
import '../../data/local/local_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import 'web_excel_parser.dart';
import 'web_file_upload_picker.dart';
import 'web_file_upload_picker_model.dart';

/// Web-only "Хүлээж авах" packing list import.
///
/// Imports the supplier's packing list (a barcodes-only file from Levi's,
/// Crocs, Adidas, ...) and saves each row as a `kind=packing_list` scan
/// against the selected task. Later, when the operator scans the same
/// shipment with the C5 reader, the receiving tab matches the decoded
/// barcodes from those EPC reads against this list to figure out which
/// items are matched / pending / over / orphan.
///
/// We deliberately keep this screen separate from the
/// `WebBarcodeEpcImportScreen`: that one converts barcodes → EPCs and the
/// EPC encoding logic took several rounds to stabilise. This screen does
/// no encoding at all — it just stores `(barcode, qty, item_code, name,
/// carton)` tuples.
class WebPackingListImportScreen extends ConsumerStatefulWidget {
  const WebPackingListImportScreen({super.key});

  @override
  ConsumerState<WebPackingListImportScreen> createState() =>
      _WebPackingListImportScreenState();
}

class _ParsedPackingRow {
  _ParsedPackingRow({
    required this.rowIndex,
    required this.rawBarcode,
    required this.qty,
    this.itemCode,
    this.name,
    this.carton,
    this.error,
  });

  final int rowIndex;
  final String rawBarcode;
  final int qty;
  final String? itemCode;
  final String? name;
  final String? carton;
  final String? error;

  String get barcode => rawBarcode.trim();

  bool get ok =>
      error == null && barcode.isNotEmpty && qty > 0 && barcode.length >= 6;
}

class _WebPackingListImportScreenState
    extends ConsumerState<WebPackingListImportScreen> {
  final _api = ScansApi();
  final _batchController = TextEditingController();

  List<_ParsedPackingRow> _rows = [];
  String _fileName = '';
  bool _loading = false;
  bool _saving = false;

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('Энэ хэсэг зөвхөн web дээр ажиллана.')),
      );
    }

    final tasks = ref.watch(tasksProvider);
    final selectedTask = ref.watch(selectedTaskProvider);
    final okRows = _rows.where((r) => r.ok).length;
    final totalQty = _rows.where((r) => r.ok).fold<int>(0, (m, r) => m + r.qty);
    // After saving we collapse rows by barcode (sum qty), so the operator
    // also sees how many distinct SKUs the packing list contains.
    final distinctBarcodes =
        _rows.where((r) => r.ok).map((r) => r.barcode).toSet().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Хүлээж авах — Packing list оруулах'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Packing list оруулах',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Levi\'s, Crocs, Adidas зэрэг ханган нийлүүлэгчийн илгээсэн '
                    'packing list-г Excel/CSV хэлбэрээр оруулна. Файлд '
                    'baркод болон тоо ширхэг (qty) байхад л хангалттай — '
                    'нэмэлтээр бараа нэр, item code, carton # таниулна. '
                    'Ижил баркод давтагдвал нэг мөр болж нийлүүлсэн нийт qty '
                    'хадгалагдана. Дараа нь C5 уншигчаар уншсан EPC-ийг '
                    'эдгээр баркодтай тулгана.',
                  ),
                  const SizedBox(height: 16),
                  _taskCard(tasks, selectedTask),
                  const SizedBox(height: 12),
                  _settingsCard(),
                  const SizedBox(height: 12),
                  _actionsCard(selectedTask, totalQty),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Preview: $okRows/${_rows.length} мөр OK · '
                      '$distinctBarcodes ялгаатай баркод · нийт qty: $totalQty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _previewTable(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskCard(List<TaskInfo> tasks, TaskInfo? selectedTask) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          initialValue: selectedTask?.id,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Task сонгох',
          ),
          items: [
            for (final t in tasks.where((e) => e.isOpen))
              DropdownMenuItem(value: t.id, child: Text(t.name)),
          ],
          onChanged: (id) {
            if (id == null) return;
            final found = tasks.firstWhere((e) => e.id == id);
            ref.read(selectedTaskProvider.notifier).state = found;
          },
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _batchController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Batch / shipment нэр (сонголттой)',
            hintText: 'Жишээ: Levis SS26 carton-12',
          ),
        ),
      ),
    );
  }

  Widget _actionsCard(TaskInfo? selectedTask, int totalQty) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _pickFile,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_loading ? 'Уншиж байна...' : 'Excel/CSV сонгох'),
            ),
            if (_fileName.isNotEmpty) Chip(label: Text(_fileName)),
            FilledButton.tonalIcon(
              onPressed: (_saving || selectedTask == null || totalQty <= 0)
                  ? null
                  : () => _saveAll(selectedTask),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_saving ? 'Хадгалж байна...' : 'Хадгалах ($totalQty qty)'),
            ),
            if (_rows.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() {
                  _rows = [];
                  _fileName = '';
                }),
                icon: const Icon(Icons.clear_all),
                label: const Text('Цэвэрлэх'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Barcode')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Item code')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Carton')),
            DataColumn(label: Text('Тайлбар')),
          ],
          rows: [
            for (final r in _rows)
              DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (r.ok) return Colors.green.withValues(alpha: 0.06);
                  return Colors.red.withValues(alpha: 0.06);
                }),
                cells: [
                  DataCell(Text('${r.rowIndex}')),
                  DataCell(SelectableText(r.rawBarcode)),
                  DataCell(Text('${r.qty}')),
                  DataCell(Text(r.itemCode ?? '-')),
                  DataCell(Text(r.name ?? '-')),
                  DataCell(Text(r.carton ?? '-')),
                  DataCell(Text(r.error ?? 'OK')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // File pick + parse
  // -------------------------------------------------------------------------
  Future<void> _pickFile() async {
    setState(() => _loading = true);
    var step = 'init';
    try {
      step = 'pick';
      debugPrint('[packing] step=pick opening picker');
      final PickedUploadFile? picked;
      try {
        picked = await pickFileForWebImport(
          allowedExtensions: const ['xlsx', 'xls', 'csv', 'txt'],
        );
      } catch (e, st) {
        debugPrint('[packing] picker threw: $e\n$st');
        _showMessage('Файл сонгогч алдаа: $e');
        return;
      }
      if (picked == null) {
        debugPrint('[packing] picker returned null');
        _showMessage('Файл сонгогдоогүй байна.');
        return;
      }

      step = 'read-bytes';
      final name = picked.name;
      final lower = name.toLowerCase();
      final bytes = picked.bytes;
      debugPrint('[packing] step=read-bytes name=$name size=${bytes.length}');
      if (bytes.isEmpty) {
        _showMessage('Файлын агуулга уншиж чадсангүй.');
        return;
      }

      step = 'extension-check';
      const allowed = ['.xlsx', '.xls', '.csv', '.txt'];
      if (!allowed.any(lower.endsWith)) {
        _showMessage('Дэмжигдэхгүй өргөтгөл: $name');
        return;
      }
      if (lower.endsWith('.xls')) {
        _showMessage(
          '.xls формат тогтворгүй. Файлаа Excel дээр "Save As → .xlsx" хийгээд оруулна уу.',
        );
        return;
      }

      step = 'parse';
      final List<_ParsedPackingRow> parsed;
      try {
        if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
          parsed = _parseCsv(bytes);
        } else {
          parsed = await _parseXlsx(bytes);
        }
      } catch (e, st) {
        debugPrint('[packing] parse threw: $e\n$st');
        _showMessage('Файлыг задлаж чадсангүй: $e');
        return;
      }

      step = 'apply';
      if (parsed.isEmpty) {
        _showMessage('Унших мөр олдсонгүй. Файлын багана/өгөгдлөө шалгана уу.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _fileName = name;
      });
      _showMessage('Файл амжилттай уншигдлаа: ${parsed.length} мөр.');
    } catch (e, st) {
      debugPrint('[packing] step=$step threw: $e\n$st');
      _showMessage('Файл унших алдаа ($step): $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ParsedPackingRow> _parseCsv(Uint8List bytes) {
    final rows = parseCsvBytes(bytes);
    if (rows.isEmpty) return const [];

    // Detect columns from header row. We accept files without a header by
    // falling back to "first column = barcode, second = qty".
    final hasHeader = rows.first.any(
      (c) => c.toLowerCase().contains(RegExp(r'[a-zа-я]')),
    );

    int barcodeCol = 0;
    int? qtyCol;
    int? itemCodeCol;
    int? nameCol;
    int? cartonCol;

    if (hasHeader) {
      barcodeCol =
          detectCsvColumnByHints(rows, _barcodeHints) ?? barcodeCol;
      qtyCol = detectCsvColumnByHints(rows, _qtyHints);
      itemCodeCol = detectCsvColumnByHints(rows, _itemCodeHints);
      nameCol = detectCsvColumnByHints(rows, _nameHints);
      cartonCol = detectCsvColumnByHints(rows, _cartonHints);
    } else {
      // No header → treat row 0 as data, qty column is row[1] if any.
      qtyCol = rows.first.length > 1 ? 1 : null;
    }

    final dataRows = hasHeader ? rows.skip(1).toList() : rows;
    final out = <_ParsedPackingRow>[];
    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      try {
        final barcode = row.length > barcodeCol
            ? cleanNumericText(row[barcodeCol])
            : '';
        if (barcode.isEmpty) continue;
        final qty = (qtyCol != null && qtyCol < row.length)
            ? parseQty(cleanNumericText(row[qtyCol]))
            : 1;
        out.add(_ParsedPackingRow(
          rowIndex: i + (hasHeader ? 2 : 1),
          rawBarcode: barcode,
          qty: qty,
          itemCode: _readOptional(row, itemCodeCol),
          name: _readOptional(row, nameCol),
          carton: _readOptional(row, cartonCol),
          error: _validate(barcode, qty),
        ));
      } catch (e) {
        out.add(_ParsedPackingRow(
          rowIndex: i + (hasHeader ? 2 : 1),
          rawBarcode: row.isEmpty ? '?' : row.first,
          qty: 1,
          error: 'Мөр уншихад алдаа: $e',
        ));
      }
    }
    return out;
  }

  String? _readOptional(List<String> row, int? col) {
    if (col == null || col >= row.length) return null;
    final v = row[col].trim();
    return v.isEmpty ? null : v;
  }

  Future<List<_ParsedPackingRow>> _parseXlsx(Uint8List bytes) async {
    final decoded = decodeWorkbook(bytes);
    final sheetName = await _pickSheet(decoded.sheetNames);
    if (!mounted) throw 'UI хаагдсан.';
    if (sheetName == null) throw 'Sheet сонгогдоогүй.';

    final sheet = decoded.excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      throw 'Sheet хоосон байна.';
    }

    final maxCols =
        sheet.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (maxCols == 0) throw 'Sheet дээр багана олдсонгүй.';

    final autoBarcode =
        detectColumnByHints(sheet.rows, maxCols, _barcodeHints);
    final barcodeCol = autoBarcode ??
        await _pickColumnDialog('Баркод багана сонгох', sheet.rows, maxCols);
    if (!mounted) throw 'UI хаагдсан.';
    if (barcodeCol == null) throw 'Баркодын багана сонгогдоогүй.';

    final qtyCol = detectColumnByHints(sheet.rows, maxCols, _qtyHints);
    final itemCodeCol =
        detectColumnByHints(sheet.rows, maxCols, _itemCodeHints);
    final nameCol = detectColumnByHints(sheet.rows, maxCols, _nameHints);
    final cartonCol =
        detectColumnByHints(sheet.rows, maxCols, _cartonHints);

    final out = <_ParsedPackingRow>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        if (barcodeCol >= row.length) continue;
        final barcode = cleanNumericText(safeCellText(row[barcodeCol]));
        if (barcode.isEmpty) continue;
        final qty = (qtyCol != null && qtyCol < row.length)
            ? parseQty(cleanNumericText(safeCellText(row[qtyCol])))
            : 1;
        out.add(_ParsedPackingRow(
          rowIndex: i + 1,
          rawBarcode: barcode,
          qty: qty,
          itemCode: _readSheetOptional(row, itemCodeCol),
          name: _readSheetOptional(row, nameCol),
          carton: _readSheetOptional(row, cartonCol),
          error: _validate(barcode, qty),
        ));
      } catch (e) {
        out.add(_ParsedPackingRow(
          rowIndex: i + 1,
          rawBarcode: '?',
          qty: 1,
          error: 'Мөр уншихад алдаа: $e',
        ));
      }
    }
    return out;
  }

  String? _readSheetOptional(List<Data?> row, int? col) {
    if (col == null || col >= row.length) return null;
    final v = safeCellText(row[col]).trim();
    return v.isEmpty ? null : v;
  }

  String? _validate(String barcode, int qty) {
    if (barcode.length < 6) return 'Баркод хэт богино';
    if (qty <= 0) return 'Qty 0';
    return null;
  }

  // -------------------------------------------------------------------------
  // Save
  // -------------------------------------------------------------------------
  Future<void> _saveAll(TaskInfo selectedTask) async {
    setState(() => _saving = true);
    try {
      final tenantId = ref.read(authStateProvider).user?['tenant_id'] as String?;
      final projectId = await ref
          .read(tasksProvider.notifier)
          .ensureSyncedToServer(selectedTask.id, tenantId: tenantId);

      // Sum qty per barcode + remember a representative item_code/name/carton
      // for each. The DB has a UNIQUE index on (tenant, project, barcode)
      // for `packing_list`, so we want one row per barcode anyway.
      final byBarcode = <String, _MergedRow>{};
      for (final r in _rows.where((r) => r.ok)) {
        byBarcode.update(
          r.barcode,
          (existing) => existing.merge(r),
          ifAbsent: () => _MergedRow.fromRow(r),
        );
      }

      final sendId = 'WEB-PACK-${DateTime.now().millisecondsSinceEpoch}';
      final batchName = _batchController.text.trim();
      final now = DateTime.now();

      final payloads = <Map<String, dynamic>>[];
      for (final m in byBarcode.values) {
        payloads.add({
          'project_id': projectId,
          'barcode_value': m.barcode,
          'barcode_format': 'PACKING-LIST',
          'kind': ScanKind.packingList,
          'scanned_at': now.toIso8601String(),
          'notes':
              'qty: ${m.qty}${m.itemCode == null ? '' : ' | item: ${m.itemCode}'}'
              '${m.name == null ? '' : ' | name: ${m.name}'}'
              '${m.carton == null ? '' : ' | carton: ${m.carton}'}',
          'metadata': {
            'send_id': sendId,
            if (batchName.isNotEmpty) 'batch_name': batchName,
            'source_file': _fileName,
            'import_kind': 'web_packing_list',
            'expected_qty': m.qty,
            if (m.itemCode != null) 'item_code': m.itemCode,
            if (m.name != null) 'name': m.name,
            if (m.carton != null) 'carton': m.carton,
          },
        });
      }

      const chunk = 450;
      for (var i = 0; i < payloads.length; i += chunk) {
        final part = payloads.sublist(
          i,
          i + chunk > payloads.length ? payloads.length : i + chunk,
        );
        await _api.batchSync(part);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Packing list хадгалагдлаа: ${payloads.length} баркод '
            '(нийт ${byBarcode.values.fold<int>(0, (a, b) => a + b.qty)} qty)',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() {
        _rows = [];
        _fileName = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хадгалах алдаа: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // -------------------------------------------------------------------------
  // Pickers
  // -------------------------------------------------------------------------
  Future<String?> _pickSheet(List<String> names) async {
    if (names.length == 1) return names.first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sheet сонгох'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: names.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(names[i]),
              onTap: () => Navigator.pop(ctx, names[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<int?> _pickColumnDialog(
    String title,
    List<List<Data?>> rows,
    int maxCol,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView.builder(
            itemCount: maxCol,
            itemBuilder: (_, col) {
              var sample = '';
              for (var r = 1; r < rows.length && r < 6; r++) {
                if (col < rows[r].length) {
                  sample += '${safeCellText(rows[r][col])} | ';
                }
              }
              return ListTile(
                title: Text('Багана ${col + 1}'),
                subtitle: Text(sample, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, col),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _MergedRow {
  _MergedRow({
    required this.barcode,
    required this.qty,
    this.itemCode,
    this.name,
    this.carton,
  });

  factory _MergedRow.fromRow(_ParsedPackingRow r) => _MergedRow(
        barcode: r.barcode,
        qty: r.qty,
        itemCode: r.itemCode,
        name: r.name,
        carton: r.carton,
      );

  final String barcode;
  int qty;
  String? itemCode;
  String? name;
  String? carton;

  _MergedRow merge(_ParsedPackingRow r) {
    qty += r.qty;
    itemCode ??= r.itemCode;
    name ??= r.name;
    // Concatenate cartons: a single barcode can sit in multiple cartons.
    if (r.carton != null && r.carton!.isNotEmpty) {
      if (carton == null) {
        carton = r.carton;
      } else if (!carton!.split(',').map((s) => s.trim()).contains(r.carton)) {
        carton = '$carton, ${r.carton}';
      }
    }
    return this;
  }
}

const Set<String> _barcodeHints = {
  'barcode',
  'bar code',
  'gtin',
  'ean',
  'upc',
  'баркод',
  'код',
};

const Set<String> _qtyHints = {
  'qty',
  'quantity',
  'тоо',
  'ширхэг',
  'count',
  'pcs',
  'piece',
};

const Set<String> _itemCodeHints = {
  'item code',
  'item_code',
  'sku',
  'style',
  'item no',
  'item#',
  'артикул',
  'item',
};

const Set<String> _nameHints = {
  'name',
  'description',
  'desc',
  'product',
  'нэр',
};

const Set<String> _cartonHints = {
  'carton',
  'box',
  'pkg',
  'package',
  'хайрцаг',
  'carton #',
  'carton no',
};
