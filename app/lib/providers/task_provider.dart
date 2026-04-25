import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/projects_api.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isServerTaskId(String id) => _uuidPattern.hasMatch(id);

class TaskInfo {
  const TaskInfo({
    required this.id,
    required this.name,
    this.description,
    this.isOpen = true,
    this.scanCount = 0,
    this.createdAt,
  });

  factory TaskInfo.fromJson(Map<String, dynamic> json) {
    return TaskInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isOpen: json['is_open'] as bool? ?? true,
      scanCount: 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final String? description;
  final bool isOpen;
  final int scanCount;
  final DateTime? createdAt;

  TaskInfo copyWith({
    String? name,
    String? description,
    bool? isOpen,
    int? scanCount,
  }) =>
      TaskInfo(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isOpen: isOpen ?? this.isOpen,
        scanCount: scanCount ?? this.scanCount,
        createdAt: createdAt,
      );
}

class TasksNotifier extends StateNotifier<List<TaskInfo>> {
  TasksNotifier() : super([]);

  final _api = ProjectsApi();

  Future<void> loadFromServer({String? tenantId}) async {
    try {
      final result = await _api.list(tenantId: tenantId);
      final data = result['data'] as List<dynamic>;
      state = data
          .map((e) => TaskInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[TasksNotifier] Loaded ${state.length} tasks from server');
    } catch (e) {
      debugPrint('[TasksNotifier] loadFromServer failed: $e');
    }
  }

  Future<void> addTask({
    String? tenantId,
    required String name,
    String? description,
  }) async {
    // Try server first
    try {
      final result = await _api.create(
        tenantId: tenantId,
        name: name,
        description: description,
      );
      final task = TaskInfo.fromJson(result);
      state = [...state, task];
      return;
    } catch (e) {
      debugPrint('[TasksNotifier] addTask API failed: $e');
    }

    // Fallback: local only
    final task = TaskInfo(
      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      isOpen: true,
      createdAt: DateTime.now(),
    );
    state = [...state, task];
  }

  Future<void> toggleTask(String id, {String? tenantId}) async {
    final existing = state.where((task) => task.id == id).firstOrNull;
    if (existing == null) return;
    try {
      final result = await _api.update(
        id,
        tenantId: tenantId,
        isOpen: !existing.isOpen,
      );
      final updated = TaskInfo.fromJson(result);
      state = [
        for (final task in state)
          if (task.id == id)
            updated.copyWith(scanCount: task.scanCount)
          else
            task,
      ];
    } catch (e) {
      debugPrint('[TasksNotifier] toggleTask failed: $e');
    }
  }

  Future<void> deleteTask(String id, {String? tenantId}) async {
    try {
      await _api.delete(id, tenantId: tenantId);
    } catch (_) {}
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> updateTask(
    String id, {
    String? tenantId,
    String? name,
    String? description,
    bool? isOpen,
  }) async {
    try {
      final result = await _api.update(
        id,
        tenantId: tenantId,
        name: name,
        description: description,
        isOpen: isOpen,
      );
      final updated = TaskInfo.fromJson(result);
      state = [
        for (final t in state)
          if (t.id == id) updated.copyWith(scanCount: t.scanCount) else t,
      ];
    } catch (_) {}
  }

  void incrementScanCount(String taskId) {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(scanCount: t.scanCount + 1) else t,
    ];
  }

  /// If [localTaskId] is already a server UUID, returns it unchanged.
  /// Otherwise looks up the local task, creates it on the server, swaps the
  /// local id with the real UUID in state, and returns the new UUID.
  ///
  /// Throws when the task cannot be created on the server, so callers can
  /// surface the failure (e.g. skip syncing affected scans).
  Future<String> ensureSyncedToServer(
    String localTaskId, {
    String? tenantId,
  }) async {
    if (isServerTaskId(localTaskId)) return localTaskId;

    final existing = state.where((t) => t.id == localTaskId).firstOrNull;
    if (existing == null) {
      throw StateError(
        'Local task $localTaskId not found — cannot sync to server.',
      );
    }

    final result = await _api.create(
      tenantId: tenantId,
      name: existing.name,
      description: existing.description,
      isOpen: existing.isOpen,
    );
    final created = TaskInfo.fromJson(result);

    state = [
      for (final t in state)
        if (t.id == localTaskId)
          TaskInfo(
            id: created.id,
            name: created.name,
            description: created.description,
            isOpen: created.isOpen,
            scanCount: t.scanCount,
            createdAt: created.createdAt ?? t.createdAt,
          )
        else
          t,
    ];

    debugPrint(
      '[TasksNotifier] Promoted local task $localTaskId → ${created.id}',
    );
    return created.id;
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, List<TaskInfo>>((ref) {
  return TasksNotifier();
});

final selectedTaskProvider = StateProvider<TaskInfo?>((ref) => null);
