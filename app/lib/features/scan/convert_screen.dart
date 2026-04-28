import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/epc_converter.dart';
import '../../data/local/local_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/audio_service.dart';

class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  final _epcController = TextEditingController();
  final _webBarcodeController = TextEditingController();
  final _bulkErrors = <String>[];

  @override
  void dispose() {
    _epcController.dispose();
    _webBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _openC5EpcImport() async {
    _epcController.clear();
    _bulkErrors.clear();
    final batchNameController = TextEditingController(text: 'C5 EPC Batch');
    var sourceFileName = '';

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: const Text('C5 EPC import'),
          content: SizedBox(
            width: 620,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                    'Chainway C5 төхөөрөмжийн EPC жагсаалтыг Excel (.xlsx) файлаар оруулна.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: batchNameController,
                      decoration: const InputDecoration(
                        labelText: 'Batch нэр (сонголттой)',
                        hintText: 'Жишээ: Shift-A 2026-04-21',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final loaded = await _pickEpcCodesFromFile();
                            if (loaded == null) return; // user cancelled
                            if (loaded.error != null) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(loaded.error!),
                                  duration: const Duration(seconds: 6),
                                ),
                              );
                              return;
                            }
                            if (loaded.codes.isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Файлаас EPC мөр олдсонгүй. Зөв багана/өгөгдлөө шалгана уу.',
                                  ),
                                ),
                              );
                              return;
                            }
                            _epcController.text = loaded.codes.join('\n');
                            sourceFileName = loaded.fileName;
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.grid_on),
                          label: const Text('Load EPC file'),
                        ),
                      ],
                    ),
                    if (sourceFileName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Source: $sourceFileName'),
                      const SizedBox(height: 8),
                      Text('Loaded EPC: ${_epcController.text.split(RegExp(r'[\s,;]+')).where((e) => e.trim().isNotEmpty).length}'),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('EPC -> Barcode + Queue'),
            ),
          ],
        ),
      ),
    );

    if (applied != true) return;

    final selectedTask = ref.read(selectedTaskProvider);
    if (selectedTask == null || !selectedTask.isOpen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нээлттэй task сонгоно уу')),
      );
      return;
    }

    final parts = _epcController.text
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;

    var added = 0;
    var skipped = 0;
    _bulkErrors.clear();
    final scanNotifier = ref.read(scanProvider.notifier);
    final authState = ref.read(authStateProvider);

    for (final epc in parts) {
      final converted = EpcConverter.tryConvertToBarcode(epc);
      final value = converted?.value;
      if (value == null || value.isEmpty) {
        skipped++;
        _bulkErrors.add(epc);
        continue;
      }
      if (!scanNotifier.shouldAccept(value)) {
        skipped++;
        _bulkErrors.add(epc);
        continue;
      }

      scanNotifier.addScan(
        taskId: selectedTask.id,
        taskName: selectedTask.name,
        barcodeValue: value,
        barcodeFormat: 'EPC->BARCODE',
        username: authState.user?['username'] as String?,
        batchName: batchNameController.text.trim().isEmpty
            ? null
            : batchNameController.text.trim(),
        sourceFile: sourceFileName.isEmpty ? null : sourceFileName,
        kind: ScanKind.epcRead,
      );
      ref.read(tasksProvider.notifier).incrementScanCount(selectedTask.id);
      added++;
    }

    if (!mounted) return;
    if (added > 0) {
      AudioService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'C5 EPC import: $added нэмэгдлээ${skipped > 0 ? ', $skipped алгасагдлаа' : ''}',
          ),
        ),
      );
    } else {
      AudioService.instance.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk upload амжилтгүй')),
      );
    }

    if (_bulkErrors.isNotEmpty) {
      await _showBulkErrors();
    }
    batchNameController.dispose();
  }

  Future<void> _openWebBarcodeToEpcBulk() async {
    _webBarcodeController.clear();
    _bulkErrors.clear();
    var sourceFile = '';
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: const Text('Web only: Barcode -> EPC (bulk)'),
          content: SizedBox(
            width: 620,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('14 оронтой barcode бүрийг шинэ мөрөөр оруулна.'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _webBarcodeController,
                      minLines: 10,
                      maxLines: 16,
                      decoration: const InputDecoration(
                        hintText: '8806091427849\n8806091427856',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final loaded = await _pickBulkTextFromFile();
                            if (loaded == null || loaded.content.trim().isEmpty) {
                              return;
                            }
                            _webBarcodeController.text = loaded.content;
                            sourceFile = loaded.fileName;
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Load .txt/.csv'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final loaded = await _pickCodesFromExcel();
                            if (loaded == null || loaded.codes.isEmpty) return;
                            _webBarcodeController.text = loaded.codes.join('\n');
                            sourceFile = loaded.fileName;
                            setLocal(() {});
                          },
                          icon: const Icon(Icons.grid_on),
                          label: const Text('Load .xlsx'),
                        ),
                      ],
                    ),
                    if (sourceFile.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Source: $sourceFile'),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Convert'),
            ),
          ],
        ),
      ),
    );
    if (applied != true) return;

    final parts = _webBarcodeController.text
        .split(RegExp(r'[\s,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;

    final convertedRows = <String>[];
    _bulkErrors.clear();
    for (final barcode in parts) {
      final converted = EpcConverter.tryConvertToEpc(barcode);
      if (converted == null) {
        _bulkErrors.add(barcode);
        continue;
      }
      convertedRows.add('${barcode}\t${converted.value}');
    }

    final report = StringBuffer('BARCODE\tEPC\n');
    for (final row in convertedRows) {
      report.writeln(row);
    }
    await Clipboard.setData(ClipboardData(text: report.toString()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Web bulk convert: ${convertedRows.length} хөрвүүллээ, '
          '${_bulkErrors.length} алгасагдлаа. (Clipboard руу хууллаа)',
        ),
      ),
    );
    if (_bulkErrors.isNotEmpty) {
      await _showBulkErrors();
    }
  }

  Future<void> _quickCreateTask() async {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final jobCodeController = TextEditingController();
    final noteController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Шинэ task үүсгэх'),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: companyController,
                    decoration: const InputDecoration(labelText: 'Компани'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: jobCodeController,
                    decoration: const InputDecoration(labelText: 'Job код'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Task нэр'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'Тайлбар (сонголттой)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true) {
      nameController.dispose();
      companyController.dispose();
      jobCodeController.dispose();
      noteController.dispose();
      return;
    }

    final company = companyController.text.trim();
    final jobCode = jobCodeController.text.trim();
    final taskName = nameController.text.trim();
    if (taskName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task нэр заавал оруулна')),
        );
      }
      nameController.dispose();
      companyController.dispose();
      jobCodeController.dispose();
      noteController.dispose();
      return;
    }

    final composedName = [
      if (company.isNotEmpty) company,
      if (jobCode.isNotEmpty) jobCode,
      taskName,
    ].join(' | ');
    final composedDesc = [
      if (company.isNotEmpty) 'Company: $company',
      if (jobCode.isNotEmpty) 'Job: $jobCode',
      if (noteController.text.trim().isNotEmpty) noteController.text.trim(),
    ].join('\n');

    await ref.read(tasksProvider.notifier).addTask(
          name: composedName,
          description: composedDesc.isEmpty ? null : composedDesc,
        );
    final tasks = ref.read(tasksProvider);
    final createdTask = tasks.lastOrNull;
    if (createdTask != null) {
      ref.read(selectedTaskProvider.notifier).state = createdTask;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task үүсгэлээ')),
      );
    }

    nameController.dispose();
    companyController.dispose();
    jobCodeController.dispose();
    noteController.dispose();
  }

  Future<({String content, String fileName})?> _pickBulkTextFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['txt', 'csv'],
      );
      final file = result?.files.firstOrNull;
      if (file?.bytes == null) return null;
      return (
        content: utf8.decode(file!.bytes!, allowMalformed: true),
        fileName: file.name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<({List<String> codes, String fileName})?> _pickCodesFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      final file = result?.files.firstOrNull;
      if (file?.bytes == null) return null;

      final excel = Excel.decodeBytes(file!.bytes!);
      if (excel.tables.isEmpty) return null;
      final selectedSheetName = await _pickExcelSheet(excel.tables.keys.toList());
      if (selectedSheetName == null) return null;
      final sheet = excel.tables[selectedSheetName];
      if (sheet == null || sheet.rows.isEmpty) return null;

      final maxColumns = sheet.rows.fold<int>(
        0,
        (m, r) => r.length > m ? r.length : m,
      );
      if (maxColumns == 0) return null;

      final autoColumn = _detectBestEpcColumn(sheet.rows, maxColumns);
      final selectedColumn =
          autoColumn ?? await _pickExcelColumn(sheet.rows, maxColumns);
      if (selectedColumn == null) return null;

      final codes = <String>[];
      for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (selectedColumn >= row.length) continue;
        final raw = (row[selectedColumn]?.value ?? '').toString().trim();
        if (raw.isNotEmpty) codes.add(raw);
      }
      return (codes: codes, fileName: file.name);
    } catch (_) {
      return null;
    }
  }

  Future<({List<String> codes, String fileName, String? error})?>
      _pickEpcCodesFromFile() async {
    PlatformFile? file;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv', 'txt'],
      );
      file = result?.files.firstOrNull;
      if (file == null) return null; // user cancelled
    } catch (e) {
      return (
        codes: const <String>[],
        fileName: '',
        error: 'Файл сонгох үед алдаа гарлаа: $e',
      );
    }

    final name = file.name;
    final lower = name.toLowerCase();
    final bytes = file.bytes;
    if (bytes == null) {
      return (
        codes: const <String>[],
        fileName: name,
        error:
            'Файлын агуулга (bytes) ирсэнгүй. Android content provider-т асуудал гарсан байж болзошгүй.',
      );
    }

    if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
      try {
        final text = utf8.decode(bytes, allowMalformed: true);
        final codes = text
            .split(RegExp(r'[\s,;]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return (codes: codes, fileName: name, error: null);
      } catch (e) {
        return (
          codes: const <String>[],
          fileName: name,
          error: 'CSV/TXT уншиж чадсангүй: $e',
        );
      }
    }

    if (lower.endsWith('.xls') && !lower.endsWith('.xlsx')) {
      return (
        codes: const <String>[],
        fileName: name,
        error:
            'Хуучин .xls (Excel 97-2003) форматыг дэмжихгүй. Файлаа .xlsx болгон хадгалаад дахин оруулна уу.',
      );
    }

    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return (
        codes: const <String>[],
        fileName: name,
        error: 'Excel parse амжилтгүй: $e',
      );
    }

    if (excel.tables.isEmpty) {
      return (
        codes: const <String>[],
        fileName: name,
        error: 'Excel дотор sheet алга.',
      );
    }

    final selectedSheetName = await _pickExcelSheet(excel.tables.keys.toList());
    if (selectedSheetName == null) return null;
    final sheet = excel.tables[selectedSheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      return (
        codes: const <String>[],
        fileName: name,
        error: 'Sheet хоосон байна.',
      );
    }

    final maxColumns = sheet.rows.fold<int>(
      0,
      (m, r) => r.length > m ? r.length : m,
    );
    if (maxColumns == 0) {
      return (
        codes: const <String>[],
        fileName: name,
        error: 'Багана олдсонгүй.',
      );
    }

    final autoColumn = _detectBestEpcColumn(sheet.rows, maxColumns);
    final selectedColumn =
        autoColumn ?? await _pickExcelColumn(sheet.rows, maxColumns);
    if (selectedColumn == null) return null;

    final codes = <String>[];
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      if (selectedColumn >= row.length) continue;
      final raw = (row[selectedColumn]?.value ?? '').toString().trim();
      if (raw.isNotEmpty) codes.add(raw);
    }
    return (codes: codes, fileName: name, error: null);
  }

  Future<String?> _pickExcelSheet(List<String> sheetNames) {
    if (sheetNames.length == 1) return Future.value(sheetNames.first);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel Sheet сонгох'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sheetNames.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              title: Text(sheetNames[i]),
              onTap: () => Navigator.pop(context, sheetNames[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  int? _detectBestEpcColumn(List<List<Data?>> rows, int maxColumns) {
    if (rows.isEmpty || maxColumns == 0) return null;

    final headerCandidates = <String>{
      'epc',
      'epc_code',
      'epccode',
      'tag',
      'tag_epc',
      'rfid',
      'uid',
      'serial',
    };

    final firstRow = rows.first;
    for (var i = 0; i < maxColumns; i++) {
      final header =
          i < firstRow.length ? (firstRow[i]?.value ?? '').toString().trim() : '';
      if (header.isEmpty) continue;
      final normalized = header.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
      if (headerCandidates.contains(normalized) ||
          normalized.contains('epc') ||
          normalized.contains('rfid')) {
        return i;
      }
    }

    // Fallback: choose the column with most EPC-looking hex values.
    final epcLike = RegExp(r'^[A-Fa-f0-9]{16,40}$');
    var bestColumn = -1;
    var bestScore = 0;
    for (var col = 0; col < maxColumns; col++) {
      var score = 0;
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (col >= row.length) continue;
        final raw = (row[col]?.value ?? '').toString().trim();
        if (epcLike.hasMatch(raw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestColumn = col;
      }
    }
    return bestScore > 0 ? bestColumn : null;
  }

  Future<int?> _pickExcelColumn(List<List<Data?>> rows, int maxColumns) {
    final headers = <String>[];
    final firstRow = rows.first;
    for (var i = 0; i < maxColumns; i++) {
      final letter = String.fromCharCode('A'.codeUnitAt(0) + i);
      final head = i < firstRow.length ? (firstRow[i]?.value ?? '').toString().trim() : '';
      headers.add(head.isEmpty ? 'Column $letter' : '$letter: $head');
    }

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel багана сонгох'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: headers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              title: Text(headers[i]),
              onTap: () => Navigator.pop(context, i),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkErrors() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Алгасагдсан мөрүүд'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _bulkErrors.length.clamp(0, 60),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              dense: true,
              title: Text(
                _bulkErrors[i],
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTask = ref.watch(selectedTaskProvider);
    final tasks = ref.watch(tasksProvider).where((t) => t.isOpen).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(kIsWeb ? 'Convert / Import' : 'C5 EPC Import'),
        actions: [
          IconButton(
            tooltip: 'Task шинэчлэх',
            onPressed: () => ref.read(tasksProvider.notifier).loadFromServer(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mobile: C5 EPC only',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Энэ хэсэг нь зөвхөн Chainway C5 төхөөрөмжөөс уншигдсан EPC-г '
                    'систем рүү оруулах зориулалттай. Single хөрвүүлэлт байхгүй.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulk convert + queue', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskInfo>(
                    value: selectedTask != null &&
                            tasks.any((t) => t.id == selectedTask.id)
                        ? selectedTask
                        : null,
                    decoration: const InputDecoration(labelText: 'Task сонгох'),
                    items: tasks
                        .map(
                          (t) => DropdownMenuItem<TaskInfo>(
                            value: t,
                            child: Text(t.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (t) =>
                        ref.read(selectedTaskProvider.notifier).state = t,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openC5EpcImport,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('C5 EPC import'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _quickCreateTask,
                        icon: const Icon(Icons.add_task),
                        label: const Text('Task үүсгэх'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Web only tool',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Barcode -> EPC bulk хөрвүүлэлт зөвхөн web дээр байна. '
                      'Mobile дээр зориуд идэвхгүй.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _openWebBarcodeToEpcBulk,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Barcode -> EPC bulk (Web)'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
