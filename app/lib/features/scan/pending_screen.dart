import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/ui_state_widgets.dart';
import '../../widgets/ui_surfaces.dart';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _busy = false;
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _syncAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(scanProvider.notifier).syncPending();
      if (!mounted) return;
      if (result.sent > 0) {
        AudioService.instance.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.sent} скан амжилттай илгээгдлээ!')),
        );
      } else if (result.failed > 0) {
        AudioService.instance.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.failed} скан илгээж чадсангүй')),
        );
      }
    } catch (_) {
      AudioService.instance.playError();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Илгээх амжилтгүй')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showBatchDetails(String sendId) async {
    final scans = ref
        .read(scanProvider)
        .where((scan) => scan.sendId == sendId)
        .toList()
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Batch',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sendId,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy send ID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: sendId));
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Send ID хуулагдлаа')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${scans.length} мөр энэ илгээлтэд багтсан байна.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.go(
                        '/data?sendId=${Uri.encodeQueryComponent(sendId)}',
                      );
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Data view'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _buildBatchTsv(scans)),
                      );
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Batch data clipboard руу хуулагдлаа'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('Batch copy'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: scans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        scan.barcodeValue,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF142018),
                        ),
                      ),
                      subtitle: Text(
                        '${scan.notes ?? '-'} • ${_formatDateTime(scan.scannedAt)}',
                      ),
                      trailing: Text(
                        scan.synced ? 'Synced' : 'Pending',
                        style: TextStyle(
                          color: scan.synced
                              ? const Color(0xFF0F8B68)
                              : const Color(0xFFB84C4C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildBatchTsv(List<dynamic> scans) {
    final rows = <String>[
      'Send ID\tBarcode\tTask\tTime\tStatus',
    ];
    for (final scan in scans) {
      rows.add(
        '${scan.sendId ?? '-'}\t${scan.barcodeValue}\t${scan.notes ?? '-'}\t${_formatDateTime(scan.scannedAt)}\t${scan.synced ? 'Synced' : 'Pending'}',
      );
    }
    return rows.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(scanProvider);
    final selectedTask = ref.watch(selectedTaskProvider);
    final query = _queryController.text.trim().toLowerCase();
    final pending = scans.where((s) => !s.synced).where((scan) {
      if (query.isEmpty) return true;
      return scan.barcodeValue.toLowerCase().contains(query) ||
          (scan.sendId ?? '').toLowerCase().contains(query);
    }).toList();
    final syncedCount = scans.where((s) => s.synced).length;
    final latestPending = pending.isEmpty
        ? null
        : pending
            .map((scan) => scan.scannedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Queue (${pending.length})'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'History',
            onPressed: () => context.go('/history'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _hero(
            context,
            count: pending.length,
            taskName: selectedTask?.name,
            latestPending: latestPending,
          ),
          const SizedBox(height: 18),
          _sessionStrip(context, pending.length, syncedCount),
          const SizedBox(height: 12),
          TextField(
            controller: _queryController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Barcode эсвэл send ID хайх',
            ),
          ),
          const SizedBox(height: 18),
          if (pending.isNotEmpty)
            FilledButton.icon(
              onPressed: _busy ? null : _syncAll,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _busy
                    ? 'Илгээж байна...'
                    : 'Бүгдийг илгээх (${pending.length})',
              ),
            ),
          const SizedBox(height: 18),
          if (pending.isEmpty)
            const AppEmptyView(
              icon: Icons.check_circle_outline,
              title: 'Хүлээгдэж буй скан байхгүй',
              message: 'Бүх queue sync хийгдсэн байна.',
            )
          else
            ...pending.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _pendingCard(context, pending.length - i, s),
              );
            }),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required int count,
    required String? taskName,
    required DateTime? latestPending,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A2C17), Color(0xFF8C5E16)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending transmissions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '$count item${count == 1 ? '' : 's'} waiting for sync',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            taskName == null
                ? 'Task сонгогдоогүй байна.'
                : 'Одоогийн session: $taskName',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(220),
                ),
          ),
          if (latestPending != null) ...[
            const SizedBox(height: 8),
            Text(
              'Сүүлд queue-д орсон: ${_formatDateTime(latestPending)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionStrip(
      BuildContext context, int pendingCount, int syncedCount) {
    return AppSurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          AppInfoPill(icon: Icons.cloud_upload, label: '$pendingCount pending'),
          AppInfoPill(icon: Icons.cloud_done, label: '$syncedCount synced'),
          ActionChip(
            avatar: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scan руу буцах'),
            onPressed: () => context.go('/scan'),
          ),
          ActionChip(
            avatar: const Icon(Icons.history, size: 16),
            label: const Text('History харах'),
            onPressed: () => context.go('/history'),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(BuildContext context, int order, dynamic s) {
    final dt = s.scannedAt;
    final time = '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFB87416).withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$order',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.barcodeValue,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s.notes ?? ''} • $time',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((s.sendId ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showBatchDetails(s.sendId!),
                    child: Text(
                      'Send ID: ${s.sendId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                if (s.error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Устгах',
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(scanProvider.notifier).removeScan(s.id),
          ),
        ],
      ),
    );
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
