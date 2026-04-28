import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/epc_converter.dart';
import '../../data/local/local_scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/audio_service.dart';
import '../../services/chainway_uhf_service.dart';

/// Live UHF scanning screen backed by the native Chainway plugin.
///
/// Replicates the core behaviour of Chainway's App Center "UHF" module:
/// pressing the hardware trigger (or the on-screen Start button) begins a
/// realtime inventory, unique EPCs appear in a live list with read count
/// and RSSI, and the user can push the resulting batch into the existing
/// offline scan queue with a single tap.
class UhfScanScreen extends ConsumerStatefulWidget {
  const UhfScanScreen({super.key});

  @override
  ConsumerState<UhfScanScreen> createState() => _UhfScanScreenState();
}

class _UhfScanScreenState extends ConsumerState<UhfScanScreen> {
  static const int _powerMin = 5;
  static const int _powerMax = 33;
  static const int _powerDefault = 20;

  final _service = ChainwayUhfService.instance;
  final Map<String, _UhfTagRow> _tags = <String, _UhfTagRow>{};
  StreamSubscription<UhfTag>? _tagSub;
  StreamSubscription<UhfKeyEvent>? _keySub;

  // UI refresh batching: tag callbacks can fire >100x/sec so we coalesce them
  // into a single setState every _uiRefreshMs to keep the main thread free.
  static const _uiRefreshMs = 100;
  Timer? _refreshTimer;
  bool _dirty = false;
  int _totalReads = 0;

  bool _supported = false;
  bool _initializing = false;
  bool _running = false;
  bool _autoConvert = true;
  int _power = _powerDefault;
  String? _error;

  final _batchController = TextEditingController();

  int _clampPower(int v) => v.clamp(_powerMin, _powerMax);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (kIsWeb) {
      setState(() {
        _supported = false;
        _error = 'UHF reading is only available on the Chainway C5 device.';
      });
      return;
    }
    try {
      final ok = await _service.isSupported();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _supported = false;
          _error = 'DeviceAPI олдсонгүй. Апп-аа C5 төхөөрөмж дээр суулгана уу.';
        });
        return;
      }
      setState(() => _supported = true);

      _tagSub = _service.tagStream.listen(_onTag);
      _keySub = _service.keyStream.listen(_onKey);

      await _initReader();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Init алдаа: $e');
    }
  }

  Future<void> _initReader() async {
    if (!_supported || _initializing) return;
    setState(() => _initializing = true);
    try {
      await _service.init();
      final current = await _service.getPower();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        // Some firmwares return -1 before first setPower; keep a sane default.
        _power = (current == null || current < _powerMin || current > _powerMax)
            ? _power
            : current;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Reader init амжилтгүй: $e';
      });
    }
  }

  Future<void> _toggleInventory() async {
    if (!_supported) return;
    if (_running) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      await _service.startInventory();
      if (!mounted) return;
      _startRefreshTimer();
      setState(() {
        _running = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Start амжилтгүй: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _service.stopInventory();
    } finally {
      _stopRefreshTimer();
      if (mounted) setState(() => _running = false);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(milliseconds: _uiRefreshMs),
      (_) {
        if (!mounted) return;
        if (_dirty) {
          _dirty = false;
          setState(() {});
        }
      },
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_dirty) {
      _dirty = false;
      if (mounted) setState(() {});
    }
  }

  void _onTag(UhfTag tag) {
    final epc = tag.epc.trim();
    if (epc.isEmpty) return;
    _totalReads += 1;
    final existing = _tags[epc];
    if (existing != null) {
      existing.count += 1;
      if (tag.rssi.isNotEmpty) existing.rssi = tag.rssi;
      existing.lastSeen = DateTime.now();
    } else {
      _tags[epc] = _UhfTagRow(
        epc: epc,
        rssi: tag.rssi,
        count: 1,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      // Fire-and-forget beep for new unique tag; never awaited.
      unawaited(AudioService.instance.playBeep());
    }
    // Don't rebuild here — the refresh timer picks up the changes at _uiRefreshMs.
    _dirty = true;
  }

  void _onKey(UhfKeyEvent event) {
    if (event.action == UhfKeyAction.down) {
      _toggleInventory();
    }
  }

  Future<void> _changePower(int v) async {
    final clamped = _clampPower(v);
    setState(() => _power = clamped);
    try {
      await _service.setPower(clamped);
    } catch (_) {}
  }

  void _clear() {
    setState(() {
      _tags.clear();
      _totalReads = 0;
    });
  }

  Future<void> _pushToQueue() async {
    final selected = ref.read(selectedTaskProvider);
    if (selected == null || !selected.isOpen) {
      _snack('Нээлттэй task сонгоно уу');
      return;
    }
    if (_tags.isEmpty) {
      _snack('Унших tag алга');
      return;
    }

    final scans = ref.read(scanProvider.notifier);
    final tasks = ref.read(tasksProvider.notifier);
    final auth = ref.read(authStateProvider);
    final batchName = _batchController.text.trim();

    var added = 0;
    var skipped = 0;
    for (final row in _tags.values.toList()) {
      String value = row.epc;
      String format = 'EPC';
      if (_autoConvert) {
        final converted = EpcConverter.tryConvertToBarcode(row.epc);
        final barcode = converted?.value;
        if (barcode != null && barcode.isNotEmpty) {
          value = barcode;
          format = 'EPC->BARCODE';
        }
      }
      if (!scans.shouldAccept(value)) {
        skipped++;
        continue;
      }
      scans.addScan(
        taskId: selected.id,
        taskName: selected.name,
        barcodeValue: value,
        barcodeFormat: format,
        username: auth.user?['username'] as String?,
        batchName: batchName.isEmpty ? null : batchName,
        sourceFile: 'UHF live',
        kind: ScanKind.epcRead,
      );
      tasks.incrementScanCount(selected.id);
      added++;
    }

    if (!mounted) return;
    if (added > 0) AudioService.instance.playSuccess();
    _snack('Нэмэгдсэн: $added, алгассан: $skipped');
    if (added > 0) {
      setState(() {
        _tags.clear();
        _totalReads = 0;
      });
      _batchController.clear();
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tagSub?.cancel();
    _keySub?.cancel();
    _batchController.dispose();
    if (_running) {
      _service.stopInventory();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(selectedTaskProvider);
    final tasks = ref.watch(tasksProvider);
    final unique = _tags.length;
    final total = _totalReads;

    if (kIsWeb) {
      return _buildUnsupported(
        'UHF уншилт зөвхөн Chainway C5 төхөөрөмж дээр ажиллана.',
      );
    }
    if (!_supported && _error != null) {
      return _buildUnsupported(_error!);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'C5 UHF',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan товчийг дарж эсвэл доор Start-ыг дарж EPC-уудыг live унших',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildTaskPicker(tasks, selected),
            const SizedBox(height: 12),
            _buildControls(scheme, unique, total),
            const SizedBox(height: 12),
            if (_error != null) _buildError(_error!),
            Expanded(child: _buildList(scheme)),
            const SizedBox(height: 8),
            _buildBottomActions(selected, unique),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskPicker(List<TaskInfo> tasks, TaskInfo? selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selected?.id,
          hint: const Text('Task сонгох'),
          items: tasks
              .where((t) => t.isOpen)
              .map(
                (t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (id) {
            final t = tasks.firstWhere((e) => e.id == id);
            ref.read(selectedTaskProvider.notifier).state = t;
          },
        ),
      ),
    );
  }

  Widget _buildControls(ColorScheme scheme, int unique, int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        _running ? scheme.error : scheme.primary,
                  ),
                  onPressed: _initializing ? null : _toggleInventory,
                  icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(
                    _initializing
                        ? 'Init...'
                        : (_running ? 'Зогсоох' : 'Start'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                ),
                onPressed: _tags.isEmpty ? null : _clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Unique EPC', value: '$unique'),
              const SizedBox(width: 12),
              _Stat(label: 'Уншилт', value: '$total'),
              const SizedBox(width: 12),
              _Stat(label: 'Power', value: '$_power dBm'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt_outlined, size: 18),
              Expanded(
                child: Slider(
                  value: _clampPower(_power).toDouble(),
                  min: _powerMin.toDouble(),
                  max: _powerMax.toDouble(),
                  divisions: _powerMax - _powerMin,
                  label: '$_power dBm',
                  onChanged: _initializing
                      ? null
                      : (v) => setState(() => _power = _clampPower(v.round())),
                  onChangeEnd: (v) => _changePower(v.round()),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text('$_power', textAlign: TextAlign.end),
              ),
            ],
          ),
          Row(
            children: [
              Switch(
                value: _autoConvert,
                onChanged: (v) => setState(() => _autoConvert = v),
              ),
              const SizedBox(width: 4),
              const Expanded(child: Text('EPC → Barcode автомат хувиргах')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme scheme) {
    if (_tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors, size: 72, color: scheme.primary.withAlpha(90)),
            const SizedBox(height: 12),
            Text(
              _running ? 'Tag унших гэж байна...' : 'EPC жагсаалт хоосон',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    final rows = _tags.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = rows[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.epc,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'RSSI: ${r.rssi.isEmpty ? '—' : r.rssi}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${r.count}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _tags.remove(r.epc)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(TaskInfo? selected, int unique) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _batchController,
          decoration: const InputDecoration(
            labelText: 'Batch нэр (сонголттой)',
            hintText: 'Жишээ: Shift-A 2026-04-21',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: (selected == null || !selected.isOpen || unique == 0)
              ? null
              : _pushToQueue,
          icon: const Icon(Icons.save_alt),
          label: Text('Pending queue руу илгээх ($unique)'),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
          TextButton(
            onPressed: () async {
              setState(() => _error = null);
              await _initReader();
            },
            child: const Text('Дахин'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupported(String msg) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sensors_off, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UhfTagRow {
  _UhfTagRow({
    required this.epc,
    required this.rssi,
    required this.count,
    required this.firstSeen,
    required this.lastSeen,
  });

  final String epc;
  String rssi;
  int count;
  final DateTime firstSeen;
  DateTime lastSeen;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
