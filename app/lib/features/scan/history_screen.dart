import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_state_widgets.dart';
import '../../widgets/ui_surfaces.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
                      trailing: const Text(
                        'Synced',
                        style: TextStyle(
                          color: Color(0xFF0F8B68),
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
    final query = _queryController.text.trim().toLowerCase();
    final synced = scans.where((s) => s.synced).where((scan) {
      if (query.isEmpty) return true;
      return scan.barcodeValue.toLowerCase().contains(query) ||
          (scan.sendId ?? '').toLowerCase().contains(query);
    }).toList();
    final pendingCount = scans.where((s) => !s.synced).length;
    final selectedTask = ref.watch(selectedTaskProvider);
    final latestSynced = synced.isEmpty
        ? null
        : synced
            .map((scan) => scan.scannedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan History (${synced.length})'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
          ),
          if (synced.isNotEmpty)
            IconButton(
              tooltip: 'Цэвэрлэх',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AppConfirmDialog(
                    title: S.clearHistory,
                    message: 'Илгээсэн бүх түүхийг устгах уу?',
                    confirmLabel: S.clear,
                  ),
                );
                if (confirmed == true) {
                  ref.read(scanProvider.notifier).clearSynced();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          _hero(
            context,
            count: synced.length,
            taskName: selectedTask?.name,
            latestSynced: latestSynced,
          ),
          const SizedBox(height: 18),
          _sessionStrip(context, synced.length, pendingCount),
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
          if (synced.isEmpty)
            const AppEmptyView(
              icon: Icons.history,
              title: 'Илгээсэн скан байхгүй',
              message: 'Sync хийгдсэн бичлэг хараахан алга.',
            )
          else
            ...synced.map((s) {
              final dt = s.scannedAt;
              final date = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
              final time =
                  '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F8B68).withAlpha(18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.check, color: Color(0xFF0F8B68)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.barcodeValue,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.notes ?? ''} • $date $time',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if ((s.sendId ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _showBatchDetails(s.sendId!),
                                child: Text(
                                  'Send ID: ${s.sendId}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontFamily: 'monospace',
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
    required DateTime? latestSynced,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F6C5A), Color(0xFF1F4D40)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirmed transmissions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '$count synced record${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            taskName == null
                ? 'Task сонгогдоогүй байна.'
                : 'Session: $taskName',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(220),
                ),
          ),
          if (latestSynced != null) ...[
            const SizedBox(height: 8),
            Text(
              'Сүүлд амжилттай илгээгдсэн: ${_formatDateTime(latestSynced)}',
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
      BuildContext context, int syncedCount, int pendingCount) {
    return AppSurfaceCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          AppInfoPill(icon: Icons.cloud_done, label: '$syncedCount synced'),
          AppInfoPill(icon: Icons.cloud_upload, label: '$pendingCount pending'),
          ActionChip(
            avatar: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scan руу буцах'),
            onPressed: () => context.go('/scan'),
          ),
          ActionChip(
            avatar: const Icon(Icons.sync_problem, size: 16),
            label: const Text('Queue харах'),
            onPressed: () => context.go('/pending'),
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
