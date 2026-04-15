import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/ui_dialogs.dart';
import '../../widgets/ui_state_widgets.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _queryController = TextEditingController();
  bool _showOpenOnly = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final authState = ref.watch(authStateProvider);
    final isAdmin = authState.isTenantAdmin;
    final selectedTask = ref.watch(selectedTaskProvider);
    final scans = ref.watch(scanProvider);
    final query = _queryController.text.trim().toLowerCase();
    final filteredTasks = tasks.where((task) {
      final matchesOpen = !_showOpenOnly || task.isOpen;
      final haystack = '${task.name} ${task.description ?? ''}'.toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesOpen && matchesQuery;
    }).toList();
    final totalScans = scans.length;
    final openTasks = tasks.where((task) => task.isOpen).length;
    final closedTasks = tasks.length - openTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Board'),
        actions: [
          IconButton(
            tooltip: S.logout,
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(S.createTask),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          _hero(
            context,
            total: tasks.length,
            open: openTasks,
            totalScans: totalScans,
            selectedTask: selectedTask,
          ),
          const SizedBox(height: 18),
          _toolbar(
            context,
            total: tasks.length,
            closed: closedTasks,
            filtered: filteredTasks.length,
            query: query,
          ),
          const SizedBox(height: 18),
          if (tasks.isEmpty)
            _empty(context, isAdmin)
          else if (filteredTasks.isEmpty)
            const AppEmptyView(
              icon: Icons.search_off,
              title: 'Илэрц олдсонгүй',
              message: 'Шүүлтүүрээ өөрчлөөд даалгавруудаа дахин харна уу.',
            )
          else
            ...filteredTasks.map((task) {
              final taskScans =
                  scans.where((s) => s.projectId == task.id).toList();
              final isSelected = selectedTask?.id == task.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _taskCard(
                  context,
                  ref,
                  task: task,
                  scanCount: taskScans.length,
                  isSelected: isSelected,
                  isAdmin: isAdmin,
                  latestScanAt: taskScans.isEmpty
                      ? null
                      : taskScans
                          .map((scan) => scan.scannedAt)
                          .reduce((a, b) => a.isAfter(b) ? a : b),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required int total,
    required int open,
    required int totalScans,
    required TaskInfo? selectedTask,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173B61), Color(0xFF0F6C5A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational tasks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose the right queue,\nthen move fast.',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(color: Colors.white, fontSize: 31),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTask == null
                          ? 'Идэвхтэй ажлыг сонгоод скан эхлүүлнэ.'
                          : 'Одоогийн сонголт: ${selectedTask.name}',
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
                  _heroStat('$total', 'Tasks'),
                  const SizedBox(height: 10),
                  _heroStat('$open', 'Open'),
                  const SizedBox(height: 10),
                  _heroStat('$totalScans', 'Scans'),
                ],
              ),
            ],
          ),
          if (selectedTask != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_checked, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${selectedTask.name} сонгогдсон байна',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/scan'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _toolbar(
    BuildContext context, {
    required int total,
    required int closed,
    required int filtered,
    required String query,
  }) {
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
                    hintText: 'Task нэр эсвэл тайлбараар хайх',
                  ),
                ),
              ),
              FilterChip(
                selected: _showOpenOnly,
                label: const Text('Зөвхөн нээлттэй'),
                onSelected: (value) => setState(() => _showOpenOnly = value),
              ),
              if (query.isNotEmpty || _showOpenOnly)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Шүүлтүүр цэвэрлэх'),
                  onPressed: () {
                    _queryController.clear();
                    setState(() => _showOpenOnly = false);
                  },
                ),
              _infoPill(Icons.layers, '$filtered / $total харагдаж байна'),
              _infoPill(Icons.lock, '$closed хаалттай'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Task card бүр дээр scan volume, төлөв, action-уудыг шууд харуулав.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, bool isAdmin) {
    return AppEmptyView(
      icon: Icons.task_alt,
      title: S.noTasks,
      message: isAdmin
          ? 'Шинэ даалгавар үүсгээд scanning flow-оо эхлүүлнэ үү.'
          : 'Одоогоор ажиллах даалгавар харагдахгүй байна.',
    );
  }

  Widget _taskCard(
    BuildContext context,
    WidgetRef ref, {
    required TaskInfo task,
    required int scanCount,
    required bool isSelected,
    required bool isAdmin,
    required DateTime? latestScanAt,
  }) {
    final accent =
        task.isOpen ? const Color(0xFF0F8B68) : const Color(0xFFB84C4C);
    final selectedBg =
        Theme.of(context).colorScheme.primaryContainer.withAlpha(180);
    final completionText = latestScanAt == null
        ? 'Скан хийгдээгүй'
        : 'Сүүлд ${_formatDateTime(latestScanAt)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openTask(context, ref, task, isAdmin),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.white.withAlpha(225),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(task.isOpen ? Icons.lock_open : Icons.lock,
                        color: accent),
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
                              : 'Тайлбар оруулаагүй даалгавар',
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
                  _miniPill('$scanCount скан'),
                  _miniPill(completionText),
                  if (isSelected) _miniPill('Идэвхтэй сонголт'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openTask(context, ref, task, isAdmin),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Скан эхлүүлэх'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(selectedTaskProvider.notifier).state = task;
                      context.go('/data');
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Дата'),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Засах',
                      onPressed: () => _showEditDialog(context, ref, task),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton.filledTonal(
                      tooltip: task.isOpen ? 'Хаах' : 'Нээх',
                      onPressed: () =>
                          ref.read(tasksProvider.notifier).toggleTask(task.id),
                      icon: Icon(task.isOpen
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AppConfirmDialog(
                              title: 'Даалгавар устгах?',
                              message:
                                  '"${task.name}" даалгаврыг устгахдаа итгэлтэй байна уу?',
                              confirmLabel: S.delete,
                              destructive: true,
                            ),
                          );
                          if (confirmed == true) {
                            ref
                                .read(tasksProvider.notifier)
                                .deleteTask(task.id);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Устгах',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _miniPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
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

  void _openTask(
    BuildContext context,
    WidgetRef ref,
    TaskInfo task,
    bool isAdmin,
  ) {
    if (!task.isOpen && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Энэ даалгавар хаагдсан байна')),
      );
      return;
    }
    ref.read(selectedTaskProvider.notifier).state = task;
    context.go('/scan');
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: S.createTask,
        subtitle: 'Task name болон description-оо оруулаад шинэ queue үүсгэнэ.',
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(S.save)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: S.taskName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: S.description),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await ref.read(tasksProvider.notifier).addTask(
            name: nameController.text.trim(),
            description: descController.text.trim().isNotEmpty
                ? descController.text.trim()
                : null,
          );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
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
          subtitle: 'Task identity болон status-ийг шинэчилнэ.',
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
                decoration: InputDecoration(labelText: S.taskName),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: S.description),
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
            name: nameController.text.trim(),
            description: descController.text.trim().isNotEmpty
                ? descController.text.trim()
                : null,
            isOpen: isOpen,
          );
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
