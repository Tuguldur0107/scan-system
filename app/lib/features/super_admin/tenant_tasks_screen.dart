import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_state_widgets.dart';

class TenantTasksScreen extends ConsumerStatefulWidget {
  const TenantTasksScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TenantTasksScreen> createState() => _TenantTasksScreenState();
}

class _TenantTasksScreenState extends ConsumerState<TenantTasksScreen> {
  final _queryController = TextEditingController();
  bool _showOpenOnly = false;
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
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantBySlugProvider(widget.slug));
    if (tenant == null) {
      return Scaffold(
        appBar: AppBar(title: Text(S.tasks)),
        body: const Center(child: Text('Tenant сонгогдоогүй байна')),
      );
    }
    _ensureTenantLoaded(tenant);

    final tasks = ref.watch(tasksProvider);
    final scans = ref.watch(scanProvider);
    final query = _queryController.text.trim().toLowerCase();
    final filteredTasks = tasks.where((task) {
      final matchesOpen = !_showOpenOnly || task.isOpen;
      final haystack = '${task.name} ${task.description ?? ''}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesOpen && matchesQuery;
    }).toList();
    final openTasks = tasks.where((task) => task.isOpen).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tenant/${tenant.slug}'),
        ),
        title: Text('${S.tasks} — ${tenant.name}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: Text(S.createTask),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _hero(
            context,
            tenantName: tenant.name,
            total: tasks.length,
            open: openTasks,
            totalScans: scans.length,
          ),
          const SizedBox(height: 16),
          _toolbar(context,
              total: tasks.length, filtered: filteredTasks.length),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const AppEmptyView(
              icon: Icons.task_alt,
              title: 'Даалгавар байхгүй',
              message: 'Энэ tenant дээр шинэ task үүсгээд ажил эхлүүлнэ үү.',
            )
          else if (filteredTasks.isEmpty)
            const AppEmptyView(
              icon: Icons.search_off,
              title: 'Илэрц олдсонгүй',
              message: 'Шүүлтүүрээ өөрчлөөд task-уудаа дахин харна уу.',
            )
          else
            ...filteredTasks.map((task) {
              final taskScans =
                  scans.where((s) => s.projectId == task.id).toList();
              final latest = taskScans.isEmpty
                  ? null
                  : taskScans
                      .map((scan) => scan.scannedAt)
                      .reduce((a, b) => a.isAfter(b) ? a : b);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _taskCard(
                  context,
                  tenantSlug: tenant.slug,
                  tenantId: tenant.id,
                  task: task,
                  scanCount: taskScans.length,
                  latestScanAt: latest,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required String tenantName,
    required int total,
    required int open,
    required int totalScans,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A5F), Color(0xFF0F6C5A)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenant task operations',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  tenantName,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Task lifecycle, scan volume, data access бүгд нэг дэлгэц дээр.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withAlpha(220),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statPill('$total', 'Tasks'),
              const SizedBox(height: 8),
              _statPill('$open', 'Open'),
              const SizedBox(height: 8),
              _statPill('$totalScans', 'Scans'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context,
      {required int total, required int filtered}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Task нэрээр хайх',
              ),
            ),
          ),
          FilterChip(
            selected: _showOpenOnly,
            label: const Text('Зөвхөн нээлттэй'),
            onSelected: (value) => setState(() => _showOpenOnly = value),
          ),
          if (_queryController.text.isNotEmpty || _showOpenOnly)
            ActionChip(
              label: const Text('Шүүлтүүр цэвэрлэх'),
              onPressed: () {
                _queryController.clear();
                setState(() => _showOpenOnly = false);
              },
            ),
          _metaPill(Icons.layers, '$filtered / $total'),
        ],
      ),
    );
  }

  Widget _taskCard(
    BuildContext context, {
    required String tenantSlug,
    required String tenantId,
    required TaskInfo task,
    required int scanCount,
    required DateTime? latestScanAt,
  }) {
    final accent =
        task.isOpen ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    task.isOpen ? Icons.lock_open : Icons.lock,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        task.description?.isNotEmpty == true
                            ? task.description!
                            : 'Тайлбар оруулаагүй task',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _statusBadge(task.isOpen),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metaPill(Icons.qr_code, '$scanCount скан'),
                _metaPill(
                  Icons.schedule,
                  latestScanAt == null
                      ? 'Скан хийгдээгүй'
                      : _formatDateTime(latestScanAt),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(selectedTaskProvider.notifier).state = task;
                    context.go('/tenant/$tenantSlug/data');
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Дата'),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: () => _showEditDialog(context, tenantId, task),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Засах'),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: () => ref
                      .read(tasksProvider.notifier)
                      .toggleTask(task.id, tenantId: tenantId),
                  icon:
                      Icon(task.isOpen ? Icons.lock_outline : Icons.lock_open),
                  label: Text(task.isOpen ? 'Хаах' : 'Нээх'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'delete') {
                      _confirmDelete(context, task);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Устгах', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$value $label',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _statusBadge(bool isOpen) {
    final color = isOpen ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Нээлттэй' : 'Хаалттай',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final tenant = ref.read(activeTenantProvider);
    if (tenant == null) return;

    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: S.createTask,
        subtitle: 'Tenant-д шинэ task queue үүсгэнэ.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.save),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: S.taskName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.task),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: S.description,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await ref.read(tasksProvider.notifier).addTask(
            tenantId: tenant.id,
            name: nameController.text.trim(),
            description: descController.text.trim().isNotEmpty
                ? descController.text.trim()
                : null,
          );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String tenantId,
    TaskInfo task,
  ) async {
    final nameController = TextEditingController(text: task.name);
    final descController = TextEditingController(text: task.description ?? '');
    var isOpen = task.isOpen;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AppDialogShell(
          title: 'Даалгавар засах',
          subtitle: 'Task name, description, status-ийг шинэчилнэ.',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.save),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: S.taskName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: S.description,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isOpen,
                onChanged: (value) => setModalState(() => isOpen = value),
                title: const Text('Нээлттэй төлөв'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await ref.read(tasksProvider.notifier).updateTask(
            task.id,
            tenantId: tenantId,
            name: nameController.text.trim(),
            description: descController.text.trim().isNotEmpty
                ? descController.text.trim()
                : null,
            isOpen: isOpen,
          );
    }
  }

  Future<void> _confirmDelete(BuildContext context, TaskInfo task) async {
    final tenant = ref.read(activeTenantProvider);
    if (tenant == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Устгах',
        message: '"${task.name}" даалгаврыг устгах уу?',
        confirmLabel: S.delete,
        destructive: true,
      ),
    );
    if (result == true) {
      await ref
          .read(tasksProvider.notifier)
          .deleteTask(task.id, tenantId: tenant.id);
    }
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}
