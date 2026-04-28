import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'web_file_upload_picker.dart';
import 'web_file_upload_picker_model.dart';

import '../../core/app_strings.dart';
import '../../core/epc_converter.dart';
import '../../data/api/epc_api.dart';
import '../../data/api/scans_api.dart';
import '../../data/local/local_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';

class WebBarcodeEpcImportScreen extends ConsumerStatefulWidget {
  const WebBarcodeEpcImportScreen({super.key});

  @override
  ConsumerState<WebBarcodeEpcImportScreen> createState() =>
      _WebBarcodeEpcImportScreenState();
}

class _ParsedRow {
  _ParsedRow({
    required this.rowIndex,
    required this.rawBarcode,
    required this.qty,
    this.gtin14,
    this.sampleEpc,
    this.error,
  });

  final int rowIndex;
  final String rawBarcode;
  final int qty;
  final String? gtin14;
  final String? sampleEpc;
  final String? error;

  bool get ok => error == null && sampleEpc != null;
}

class _WebBarcodeEpcImportScreenState
    extends ConsumerState<WebBarcodeEpcImportScreen> {
  final _api = ScansApi();
  final _epcApi = EpcApi();
  final _batchController = TextEditingController();

  List<_ParsedRow> _rows = [];
  String _fileName = '';
  bool _loading = false;
  bool _saving = false;
  int _cpDigits = EpcConverter.companyPrefixDigits;

  /// Cumulative EPC count per GTIN already stored on the server for this
  /// tenant. Populated after a file is loaded and refreshed after save so the
  /// preview shows "we've already received N of this item, next will be N+1".
  Map<String, int> _existingCounts = const {};
  bool _loadingCounts = false;

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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  S.barcodeEpcImport,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Excel/CSV-с баркод уншиж GS1 SGTIN-96 EPC рүү хөрвүүлнэ. '
                  'Qty багана байвал тухайн мөр бүрээс qty хэмжээтэй EPC үүсгэнэ. '
                  'Серийн дугаар нь tenant дотроо тухайн баркодоор үргэлжилж, '
                  'эхлээд 1, дараа нь 2, 3 ... гэж тоологдоно — ингэснээр тухайн '
                  'бараа танайд нийт хэдэн ширхэг бүртгэгдсэн нь хянагдана.',
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
                    'Preview: $okRows/${_rows.length} мөр OK, нийт EPC: $totalQty',
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
    );
  }

  Widget _taskCard(List<TaskInfo> tasks, TaskInfo? selectedTask) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          initialValue: selectedTask?.id,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: S.selectTask,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GS1 SGTIN partition (Company Prefix digits)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _cpDigits,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [6, 7, 8, 9, 10, 11, 12]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _cpDigits = v;
                  EpcConverter.setCompanyPrefixDigits(v);
                  _rows = [
                    for (final r in _rows) _convertParsed(r.rowIndex, r.rawBarcode, r.qty),
                  ];
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _batchController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Batch нэр (сонголттой)',
              ),
            ),
          ],
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
              label: Text(_loading ? S.loading : 'Excel/CSV сонгох'),
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
              label: Text(_saving ? S.working : 'Хадгалах ($totalQty EPC)'),
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
            DataColumn(label: Text('GTIN-14')),
            DataColumn(label: Text('Өмнө хадгалсан')),
            DataColumn(label: Text('Серийн муж')),
            DataColumn(label: Text('Sample EPC')),
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
                  DataCell(SelectableText(r.gtin14 ?? '-')),
                  DataCell(Text(_existingFor(r))),
                  DataCell(Text(_predictedRange(r))),
                  DataCell(
                    SelectableText(
                      r.sampleEpc ?? '-',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  DataCell(Text(r.error ?? 'OK')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _existingFor(_ParsedRow r) {
    if (r.gtin14 == null) return '-';
    if (_loadingCounts) return '...';
    final n = _existingCounts[r.gtin14] ?? 0;
    return '$n';
  }

  /// Estimated serial range this row will get when saved. Multiple rows can
  /// share a GTIN, so we walk all OK rows in declared order and accumulate.
  String _predictedRange(_ParsedRow r) {
    if (!r.ok || r.gtin14 == null) return '-';
    final cursor = <String, int>{};
    for (final row in _rows.where((e) => e.ok)) {
      final base = (_existingCounts[row.gtin14] ?? 0);
      cursor.putIfAbsent(row.gtin14!, () => base);
    }
    for (final row in _rows.where((e) => e.ok)) {
      final start = cursor[row.gtin14!]! + 1;
      final end = cursor[row.gtin14!]! + row.qty;
      if (identical(row, r)) {
        return start == end ? '#$start' : '#$start..#$end';
      }
      cursor[row.gtin14!] = end;
    }
    return '-';
  }

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    // We tag every step so any future error message points to the exact
    // place that failed instead of the generic "Файл унших алдаа".
    var step = 'init';
    try {
      step = 'pick';
      debugPrint('[import] step=pick opening native browser picker');
      final PickedUploadFile? picked;
      try {
        picked = await pickFileForWebImport(
          allowedExtensions: const ['xlsx', 'xls', 'csv', 'txt'],
        );
      } catch (e, st) {
        debugPrint('[import] picker threw: $e\n$st');
        _showMessage('Файл сонгогч алдаа: $e');
        return;
      }
      if (picked == null) {
        debugPrint('[import] picker returned null');
        _showMessage('Файл сонгогдоогүй байна.');
        return;
      }

      step = 'read-bytes';
      final name = picked.name;
      final lower = name.toLowerCase();
      final bytes = picked.bytes;
      debugPrint('[import] step=read-bytes name=$name size=${bytes.length}');
      if (bytes.isEmpty) {
        _showMessage('Файлын агуулга уншиж чадсангүй. Өөр файл сонгож үзнэ үү.');
        return;
      }

      step = 'extension-check';
      const allowed = ['.xlsx', '.xls', '.csv', '.txt'];
      if (!allowed.any(lower.endsWith)) {
        _showMessage('Дэмжигдэхгүй өргөтгөл: $name (зөвхөн .xlsx/.csv/.txt).');
        return;
      }
      if (lower.endsWith('.xls')) {
        _showMessage(
          '.xls формат тогтворгүй байна. Файлаа Excel дээр "Save As -> .xlsx" хийгээд дахин оруулна уу.',
        );
        return;
      }

      step = 'parse';
      List<_ParsedRow> parsed;
      try {
        if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
          parsed = _parseCsvBytes(bytes);
        } else {
          parsed = await _parseXlsxBytes(bytes);
        }
      } catch (e, st) {
        debugPrint('[import] parse threw: $e\n$st');
        _showMessage('Файлыг задлаж чадсангүй ($step): $e');
        return;
      }

      step = 'apply';
      debugPrint('[import] step=apply parsedRows=${parsed.length}');
      if (parsed.isEmpty) {
        _showMessage('Унших мөр олдсонгүй. Файлын багана/өгөгдлөө шалгана уу.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _fileName = name;
        _existingCounts = const {};
      });

      // Counts are decorative ("how many of this barcode have we already
      // saved"). Failure to fetch them must not break the import preview, so
      // we run it as a side-effect rather than awaiting it inside the main
      // try/catch.
      unawaited(_refreshExistingCounts());

      _showMessage('Файл амжилттай уншигдлаа: ${parsed.length} мөр.');
    } catch (e, st) {
      debugPrint('[import] step=$step threw: $e\n$st');
      _showMessage('Файл унших алдаа ($step): $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reads the bytes of a CSV/TXT file and returns one `_ParsedRow` per
  /// non-empty line. Each row is wrapped in its own try so a single bad
  /// line cannot poison the whole import.
  List<_ParsedRow> _parseCsvBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final out = <_ParsedRow>[];
    var i = 0;
    for (final line in lines) {
      i++;
      try {
        final parts =
            line.split(RegExp(r'[,;\t]')).map((e) => e.trim()).toList();
        final barcode = _cleanNumericText(parts.isEmpty ? '' : parts.first);
        final qty =
            parts.length > 1 ? _parseQty(_cleanNumericText(parts[1])) : 1;
        out.add(_convertParsedSafe(i, barcode, qty));
      } catch (e) {
        out.add(_ParsedRow(
          rowIndex: i,
          rawBarcode: line,
          qty: 1,
          error: 'Мөр уншихад алдаа: $e',
        ));
      }
    }
    return out;
  }

  /// Strips Excel-export artefacts from a numeric string so digit-only
  /// post-processing doesn't accidentally turn "8888888000003.0" into
  /// "88888880000030". Handles a trailing `.0`/`.00…` and basic scientific
  /// notation (`1.23e+12`) which can appear in CSVs exported from Excel.
  String _cleanNumericText(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;

    final trailing = RegExp(r'^([+-]?\d+)\.0+$').firstMatch(s);
    if (trailing != null) return trailing.group(1)!;

    final sci = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?[eE]([+-]?\d+)$').firstMatch(s);
    if (sci != null) {
      try {
        final sign = sci.group(1) ?? '';
        final intPart = sci.group(2)!;
        final fracPart = sci.group(3) ?? '';
        final exp = int.parse(sci.group(4)!);
        final combined = '$intPart$fracPart';
        final shift = exp - fracPart.length;
        if (shift >= 0) {
          return '$sign$combined${'0' * shift}';
        }
        if (-shift >= combined.length) return '${sign}0';
        return '$sign${combined.substring(0, combined.length + shift)}';
      } catch (_) {
        return s;
      }
    }
    return s;
  }

  /// Decodes the workbook, lets the user pick a sheet/column when needed,
  /// and walks the rows. Cell `.toString()` is wrapped in `_safeCellText`
  /// because some Excel cell values (errors, formula results) can throw
  /// `Invalid argument(s): Value must be finite: NaN` when stringified.
  Future<List<_ParsedRow>> _parseXlsxBytes(Uint8List bytes) async {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      throw 'Excel decode амжилтгүй: $e';
    }
    if (excel.tables.isEmpty) {
      throw 'Excel файлд sheet олдсонгүй.';
    }

    final sheetName = await _pickSheet(excel.tables.keys.toList());
    if (!context.mounted) throw 'UI хаагдсан.';
    if (sheetName == null) throw 'Sheet сонгогдоогүй.';

    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      throw 'Sheet хоосон байна.';
    }

    final maxCols =
        sheet.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (maxCols == 0) {
      throw 'Sheet дээр багана олдсонгүй.';
    }

    final autoCol = _detectBarcodeColumn(sheet.rows, maxCols);
    final barcodeCol = autoCol ??
        await _pickColumnDialog('Баркод багана сонгох', sheet.rows, maxCols);
    if (!context.mounted) throw 'UI хаагдсан.';
    if (barcodeCol == null) throw 'Баркодын багана сонгогдоогүй.';

    final qtyCol = _detectQtyColumn(sheet.rows, maxCols);

    final out = <_ParsedRow>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        if (barcodeCol >= row.length) continue;
        // _safeCellText already strips trailing ".0" for integer doubles, but
        // we layer _cleanNumericText on top to also flatten scientific
        // notation cells ("1.23E+12") that some sheets emit.
        final barcode = _cleanNumericText(_safeCellText(row[barcodeCol]));
        if (barcode.isEmpty) continue;
        final qty = (qtyCol != null && qtyCol < row.length)
            ? _parseQty(_cleanNumericText(_safeCellText(row[qtyCol])))
            : 1;
        out.add(_convertParsedSafe(i, barcode, qty));
      } catch (e) {
        out.add(_ParsedRow(
          rowIndex: i,
          rawBarcode: '?',
          qty: 1,
          error: 'Мөр уншихад алдаа: $e',
        ));
      }
    }
    return out;
  }

  /// Reads a cell as a clean string suitable for barcode/qty parsing.
  ///
  /// Excel stores most "numbers" as doubles, so a barcode like
  /// `8888888000003` ends up as `DoubleCellValue(8888888000003.0)`.
  /// The default `.toString()` returns `"8888888000003.0"`, which the
  /// digit-stripping in `normalizeToGtin14` would turn into
  /// `"88888880000030"` — a different 14-digit value with the wrong
  /// check digit, breaking the EPC encode. We special-case each cell
  /// type so integer-valued doubles come back without the trailing `.0`.
  String _safeCellText(Data? cell) {
    try {
      final v = cell?.value;
      if (v == null) return '';

      if (v is IntCellValue) {
        return v.value.toString();
      }
      if (v is DoubleCellValue) {
        final d = v.value;
        if (d.isNaN || d.isInfinite) return '';
        if (d == d.truncateToDouble()) {
          // Integer-valued double: drop the ".0" so 8.888888e12 -> "8888888000003".
          // Use BigInt to avoid loss of precision past 2^53.
          return BigInt.from(d).toString();
        }
        return d.toString();
      }
      if (v is TextCellValue) {
        return v.value.toString();
      }
      if (v is BoolCellValue) {
        return v.value ? '1' : '0';
      }
      if (v is FormulaCellValue) {
        // We can't evaluate formulas; surfacing the formula text as a
        // barcode would be misleading.
        return '';
      }

      final s = v.toString();
      if (s == 'NaN' || s == 'Infinity' || s == '-Infinity') return '';
      return s;
    } catch (_) {
      return '';
    }
  }

  /// Same as `_convertParsed` but never throws — converts errors into a
  /// failed `_ParsedRow` instead so the table still renders. The full
  /// stack trace is dumped to the console so we can pinpoint regressions
  /// instead of seeing a generic error message.
  _ParsedRow _convertParsedSafe(int rowIndex, String rawBarcode, int qty) {
    try {
      return _convertParsed(rowIndex, rawBarcode, qty);
    } catch (e, st) {
      debugPrint(
          '[import] convert failed row=$rowIndex barcode="$rawBarcode" qty=$qty: $e\n$st');
      return _ParsedRow(
        rowIndex: rowIndex,
        rawBarcode: rawBarcode,
        qty: qty,
        error: 'Хөрвүүлэлтийн алдаа: $e',
      );
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Pulls the cumulative EPC totals per GTIN from the server so the preview
  /// can display "you've already saved N of this barcode".
  Future<void> _refreshExistingCounts() async {
    final gtins = <String>{
      for (final r in _rows.where((r) => r.ok)) r.gtin14!,
    }.toList();
    if (gtins.isEmpty) return;
    setState(() => _loadingCounts = true);
    try {
      final counts = await _epcApi.counts(gtins);
      if (!mounted) return;
      setState(() => _existingCounts = counts);
    } catch (_) {
      // Counts are decorative; failure here shouldn't block the import.
    } finally {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  _ParsedRow _convertParsed(int rowIndex, String rawBarcode, int qty) {
    final normalized = EpcConverter.normalizeToGtin14(rawBarcode);
    if (normalized == null) {
      return _ParsedRow(
        rowIndex: rowIndex,
        rawBarcode: rawBarcode,
        qty: qty,
        error: 'GTIN хэлбэр буруу',
      );
    }
    final sample = EpcConverter.encodeSgtin96FromGtin14(normalized, serial: 1);
    if (sample == null) {
      return _ParsedRow(
        rowIndex: rowIndex,
        rawBarcode: rawBarcode,
        qty: qty,
        gtin14: normalized,
        error: 'SGTIN-96 хөрвүүлэлт амжилтгүй',
      );
    }
    return _ParsedRow(
      rowIndex: rowIndex,
      rawBarcode: rawBarcode,
      qty: qty < 1 ? 1 : qty,
      gtin14: normalized,
      sampleEpc: sample.value,
    );
  }

  Future<void> _saveAll(TaskInfo selectedTask) async {
    setState(() => _saving = true);
    try {
      final tenantId = ref.read(authStateProvider).user?['tenant_id'] as String?;
      final projectId = await ref
          .read(tasksProvider.notifier)
          .ensureSyncedToServer(selectedTask.id, tenantId: tenantId);

      // Sum quantities per GTIN so the server only allocates one contiguous
      // range per barcode, even if the same GTIN appears on multiple rows.
      final goodRows = _rows.where((r) => r.ok).toList();
      final qtyByGtin = <String, int>{};
      for (final r in goodRows) {
        qtyByGtin.update(r.gtin14!, (v) => v + r.qty, ifAbsent: () => r.qty);
      }

      // Reserve the next sequential serial range per GTIN under this tenant.
      // The server bumps the persistent counter atomically, so subsequent
      // uploads will continue from where this one ends.
      final reservations = await _epcApi.reserve([
        for (final e in qtyByGtin.entries) (gtin14: e.key, qty: e.value),
      ]);
      final startByGtin = {for (final r in reservations) r.gtin14: r.start};
      final totalByGtin = {for (final r in reservations) r.gtin14: r.total};

      // Per-GTIN cursor that walks the reserved range as we encode each EPC.
      final cursor = <String, int>{...startByGtin};

      final sendId = 'WEB-EPC-${DateTime.now().millisecondsSinceEpoch}';
      final batchName = _batchController.text.trim();
      final now = DateTime.now();

      final payloads = <Map<String, dynamic>>[];
      for (final row in goodRows) {
        final gtin = row.gtin14!;
        for (var i = 0; i < row.qty; i++) {
          final serial = cursor[gtin]!;
          cursor[gtin] = serial + 1;
          final epcRes = EpcConverter.encodeSgtin96FromGtin14(gtin, serial: serial);
          if (epcRes == null) continue;
          payloads.add({
            'project_id': projectId,
            'barcode_value': epcRes.value,
            'barcode_format': 'SGTIN-96',
            'kind': ScanKind.epcImport,
            'scanned_at': now.toIso8601String(),
            'notes':
                'GTIN-14: $gtin | raw: ${row.rawBarcode} | serial: $serial | tenant total: ${totalByGtin[gtin]}',
            'metadata': {
              'send_id': sendId,
              if (batchName.isNotEmpty) 'batch_name': batchName,
              'source_file': _fileName,
              'import_kind': 'web_barcode_to_sgtin96_epc',
              'row_index': row.rowIndex,
              'source_cell': row.rawBarcode,
              'gtin14': gtin,
              'company_prefix_digits': EpcConverter.companyPrefixDigits,
              'serial': serial,
              'tenant_cumulative_total': totalByGtin[gtin],
            },
          });
        }
      }

      const chunk = 450;
      for (var i = 0; i < payloads.length; i += chunk) {
        final part = payloads.sublist(
          i,
          i + chunk > payloads.length ? payloads.length : i + chunk,
        );
        await _api.batchSync(part);
      }

      for (var i = 0; i < payloads.length; i++) {
        ref.read(tasksProvider.notifier).incrementScanCount(projectId);
      }

      // Refresh local copy of "already saved" counts so the user can keep
      // importing in the same session and see updated totals immediately.
      if (mounted) {
        setState(() => _existingCounts = {..._existingCounts, ...totalByGtin});
      }

      if (!context.mounted) return;
      final summary = reservations
          .map((r) => '${r.gtin14}: #${r.start}..#${r.end} (нийт ${r.total})')
          .join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Амжилттай: ${payloads.length} EPC хадгаллаа\n$summary'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Хадгалах алдаа: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _parseQty(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 1;
    var n = int.tryParse(s);
    if (n == null) {
      // Excel cells often surface as "5.0"; accept those too.
      final d = double.tryParse(s);
      if (d != null && d.isFinite) {
        n = d.toInt();
      }
    }
    if (n == null || n <= 0) return 1;
    if (n > 100000) return 100000;
    return n;
  }

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
            child: Text(S.cancel),
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
                  sample += '${_safeCellText(rows[r][col])} | ';
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
            child: Text(S.cancel),
          ),
        ],
      ),
    );
  }

  int? _detectBarcodeColumn(List<List<Data?>> rows, int maxColumns) {
    if (rows.isEmpty) return null;
    final first = rows.first;
    const hints = {
      'barcode',
      'bar code',
      'gtin',
      'ean',
      'upc',
      'баркод',
      'код',
    };
    for (var c = 0; c < maxColumns; c++) {
      final h =
          c < first.length ? _safeCellText(first[c]).toLowerCase() : '';
      if (h.isEmpty) continue;
      for (final hint in hints) {
        if (h.contains(hint)) return c;
      }
    }
    return 0;
  }

  int? _detectQtyColumn(List<List<Data?>> rows, int maxColumns) {
    if (rows.isEmpty) return null;
    final first = rows.first;
    const hints = {'qty', 'quantity', 'тоо', 'ширхэг', 'count'};
    for (var c = 0; c < maxColumns; c++) {
      final h =
          c < first.length ? _safeCellText(first[c]).toLowerCase() : '';
      if (h.isEmpty) continue;
      for (final hint in hints) {
        if (h.contains(hint)) return c;
      }
    }
    return null;
  }
}

