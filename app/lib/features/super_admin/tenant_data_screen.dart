import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/local_scan.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/scan_data_table.dart';
import '../../widgets/ui_state_widgets.dart';

class TenantDataScreen extends ConsumerStatefulWidget {
  const TenantDataScreen({
    super.key,
    required this.slug,
    this.initialSendId,
  });

  final String slug;
  final String? initialSendId;

  @override
  ConsumerState<TenantDataScreen> createState() => _TenantDataScreenState();
}

class _TenantDataScreenState extends ConsumerState<TenantDataScreen> {
  final _barcodeFilter = TextEditingController();
  final _sendIdFilter = TextEditingController();
  final _dateFilter = TextEditingController();
  final _taskFilter = TextEditingController();
  final _userFilter = TextEditingController();
  String? _activePreset;
  String? _loadedTenantId;

  void _ensureTenantLoaded(TenantInfo tenant) {
    if (_loadedTenantId == tenant.id) return;
    _loadedTenantId = tenant.id;
    Future.microtask(() async {
      ref.read(activeTenantProvider.notifier).state = tenant;
      await ref
          .read(tasksProvider.notifier)
          .loadFromServer(tenantId: tenant.id);
      await ref
          .read(scanProvider.notifier)
          .fetchFromServer(tenantId: tenant.id);
    });
  }

  @override
  void initState() {
    super.initState();
    if ((widget.initialSendId ?? '').trim().isNotEmpty) {
      _sendIdFilter.text = widget.initialSendId!.trim();
    }
  }

  @override
  void dispose() {
    _barcodeFilter.dispose();
    _sendIdFilter.dispose();
    _dateFilter.dispose();
    _taskFilter.dispose();
    _userFilter.dispose();
    super.dispose();
  }

  bool get _hasManualFilters =>
      _barcodeFilter.text.isNotEmpty ||
      _sendIdFilter.text.isNotEmpty ||
      _dateFilter.text.isNotEmpty ||
      _taskFilter.text.isNotEmpty ||
      _userFilter.text.isNotEmpty;

  bool get _hasFilters => _hasManualFilters || _activePreset != null;

  void _clearFilters() {
    _barcodeFilter.clear();
    _sendIdFilter.clear();
    _dateFilter.clear();
    _taskFilter.clear();
    _userFilter.clear();
    setState(() => _activePreset = null);
  }

  void _applyPreset(String preset, List<LocalScan> scans) {
    _barcodeFilter.clear();
    _sendIdFilter.clear();
    _dateFilter.clear();
    _taskFilter.clear();
    _userFilter.clear();
    _activePreset = preset;

    final now = DateTime.now();
    if (preset == 'today') {
      _dateFilter.text = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    } else if (preset == 'mine') {
      final preferredUser =
          scans.map((scan) => scan.username).whereType<String>().firstWhere(
                (value) => value.trim().isNotEmpty,
                orElse: () => '',
              );
      if (preferredUser.isNotEmpty) {
        _userFilter.text = preferredUser;
      }
    }
    setState(() {});
  }

  List<LocalScan> _applyFilters(List<LocalScan> scans) {
    var result = scans;
    final b = _barcodeFilter.text.toLowerCase();
    final sendId = _sendIdFilter.text.toLowerCase();
    final d = _dateFilter.text.toLowerCase();
    final t = _taskFilter.text.toLowerCase();
    final u = _userFilter.text.toLowerCase();

    if (b.isNotEmpty) {
      result = result
          .where((s) => s.barcodeValue.toLowerCase().contains(b))
          .toList();
    }
    if (sendId.isNotEmpty) {
      result = result
          .where((s) => (s.sendId ?? '').toLowerCase().contains(sendId))
          .toList();
    }
    if (d.isNotEmpty) {
      result = result.where((s) {
        final dt = s.scannedAt;
        final date = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
        return date.contains(d);
      }).toList();
    }
    if (t.isNotEmpty) {
      result = result
          .where((s) => (s.notes ?? '').toLowerCase().contains(t))
          .toList();
    }
    if (u.isNotEmpty) {
      result = result
          .where((s) => (s.username ?? '').toLowerCase().contains(u))
          .toList();
    }
    if (_activePreset == 'pending') {
      result = result.where((s) => !s.synced).toList();
    } else if (_activePreset == 'synced') {
      result = result.where((s) => s.synced).toList();
    } else if (_activePreset == 'with_errors') {
      result = result.where((s) => (s.error ?? '').trim().isNotEmpty).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantBySlugProvider(widget.slug));
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Data Workspace')),
        body: const Center(child: Text('Tenant сонгогдоогүй байна')),
      );
    }
    _ensureTenantLoaded(tenant);

    final selectedTask = ref.watch(selectedTaskProvider);
    final tasks = ref.watch(tasksProvider);
    final allScans = ref.watch(scanProvider);
    final scans = selectedTask != null
        ? allScans.where((s) => s.projectId == selectedTask.id).toList()
        : allScans;
    final filtered = _applyFilters(scans);
    final syncedCount = filtered.where((scan) => scan.synced).length;
    final pendingCount = filtered.where((scan) => !scan.synced).length;
    final latestScan = filtered.isEmpty
        ? null
        : filtered
            .map((scan) => scan.scannedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tenant/${tenant.slug}/tasks'),
        ),
        title: Text('${tenant.name} Data'),
        actions: [
          PopupMenuButton<TaskInfo?>(
            tooltip: 'Даалгавар сонгох',
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: (task) =>
                ref.read(selectedTaskProvider.notifier).state = task,
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Бүх task')),
              ...tasks.map((task) => PopupMenuItem(
                    value: task,
                    child: Text(task.name),
                  )),
            ],
          ),
          if (filtered.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'CSV экспорт',
              onPressed: () {
                final csv = _generateCsv(filtered);
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV хуулагдлаа')),
                );
              },
            ),
        ],
      ),
      body: scans.isEmpty
          ? AppEmptyView(
              icon: Icons.table_chart,
              title: 'Дата байхгүй байна',
              message: selectedTask != null
                  ? '"${selectedTask.name}" task дээр скан алга.'
                  : 'Tenant дээр харагдах скан бүртгэл алга.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _hero(
                  context,
                  tenantName: tenant.name,
                  taskName: selectedTask?.name ?? 'All tasks',
                  total: scans.length,
                  filtered: filtered.length,
                  latestScan: latestScan,
                ),
                const SizedBox(height: 16),
                _filterPanel(context, syncedCount, pendingCount, scans),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  AppEmptyView(
                    icon: Icons.filter_alt_off,
                    title: 'Шүүлтүүрт тохирох мөр алга',
                    message: _hasFilters
                        ? 'Шүүлтүүр эсвэл preset-ээ өөрчлөөд дахин оролдоно уу.'
                        : 'Харагдах дата алга.',
                  )
                else
                  ScanDataTable(
                    scans: filtered,
                    totalCount: scans.length,
                    onOpenDetails: (scan) => _showScanDetails(context, scan),
                  ),
              ],
            ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required String tenantName,
    required String taskName,
    required int total,
    required int filtered,
    required DateTime? latestScan,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF173B61), Color(0xFF244B7B), Color(0xFF0F6C5A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenantName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            taskName,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            latestScan == null
                ? 'Скан бүртгэл хараахан алга.'
                : 'Сүүлд шинэчлэгдсэн мөр: ${_formatDateTime(latestScan)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(220),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroPill(Icons.table_rows, '$filtered / $total мөр'),
              _heroPill(
                  Icons.filter_alt, _hasFilters ? 'Шүүлтүүртэй' : 'Бүх мөр'),
              _heroPill(Icons.touch_app, 'Мөр дээр дарж detail харна'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterPanel(
    BuildContext context,
    int syncedCount,
    int pendingCount,
    List<LocalScan> scans,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _quickMetric(
                context,
                icon: Icons.cloud_done,
                label: 'Синк хийгдсэн',
                value: '$syncedCount',
                color: const Color(0xFF0F8B68),
              ),
              _quickMetric(
                context,
                icon: Icons.cloud_upload,
                label: 'Хүлээгдэж буй',
                value: '$pendingCount',
                color: pendingCount > 0
                    ? const Color(0xFFB84C4C)
                    : const Color(0xFF7A8595),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _presetChip('today', 'Өнөөдөр', Icons.today, scans),
              _presetChip(
                  'pending', 'Хүлээгдэж буй', Icons.cloud_upload, scans),
              _presetChip('synced', 'Синк хийсэн', Icons.cloud_done, scans),
              _presetChip(
                  'with_errors', 'Алдаатай', Icons.error_outline, scans),
              _presetChip('mine', 'My scans', Icons.person, scans),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _filterField('Баркод', _barcodeFilter, Icons.qr_code),
              _filterField('Илгээсэн ID', _sendIdFilter, Icons.tag),
              _filterField('Огноо', _dateFilter, Icons.calendar_today),
              _filterField('Даалгавар', _taskFilter, Icons.task_alt),
              _filterField('Хэрэглэгч', _userFilter, Icons.person),
            ],
          ),
          if (_hasFilters) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.close),
                label: const Text('Шүүлтүүр цэвэрлэх'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetChip(
    String preset,
    String label,
    IconData icon,
    List<LocalScan> scans,
  ) {
    return FilterChip(
      selected: _activePreset == preset,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (selected) {
        if (!selected) {
          setState(() => _activePreset = null);
          return;
        }
        _applyPreset(preset, scans);
      },
    );
  }

  Widget _filterField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: 'Шүүх...',
        ),
      ),
    );
  }

  Widget _quickMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showScanDetails(BuildContext context, LocalScan scan) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan detail',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _detailRow('Barcode', scan.barcodeValue, monospace: true),
              _detailRow('Project', scan.projectId),
              _detailRow('User', scan.username ?? '-'),
              _detailRow('Time', _formatDateTime(scan.scannedAt)),
              _detailRow(
                  'Status', scan.synced ? 'Синк хийсэн' : 'Хүлээгдэж буй'),
              _detailRow(
                'Error',
                scan.error?.trim().isNotEmpty == true ? scan.error! : '-',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: scan.barcodeValue));
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Barcode хуулагдлаа')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy barcode'),
                  ),
                  if (!scan.synced)
                    FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(sheetContext);
                        await ref.read(scanProvider.notifier).syncPending();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Pending sync ажиллууллаа'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Resync'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style:
                  monospace ? const TextStyle(fontFamily: 'monospace') : null,
            ),
          ),
        ],
      ),
    );
  }

  String _generateCsv(List<LocalScan> scans) {
    final buf = StringBuffer();
    buf.writeln('#,Баркод,Огноо,Цаг,Даалгавар,Хэрэглэгч');
    for (var i = 0; i < scans.length; i++) {
      final s = scans[i];
      final dt = s.scannedAt;
      final date = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
      final time = '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
      buf.writeln(
        '${i + 1},${s.barcodeValue},$date,$time,${s.notes ?? '-'},${s.username ?? '-'}',
      );
    }
    return buf.toString();
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
