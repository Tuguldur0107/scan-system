import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/audio_service.dart';
import '../../widgets/ui_surfaces.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  MobileScannerController? _cameraController;
  Timer? _webRefreshTimer;

  bool cameraOpen = false;
  bool torchOn = false;
  String? lastDetected;
  DateTime? lastDetectedAt;
  String? _lastAdded;
  String? _feedbackMessage;
  bool _feedbackError = false;

  final _manualController = TextEditingController();
  final _manualFocus = FocusNode();

  bool get _canUseCamera => !kIsWeb;

  @override
  void initState() {
    super.initState();
    if (_canUseCamera) {
      _cameraController = MobileScannerController(autoStart: false);
    }
    if (kIsWeb) {
      _webRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchServerScans();
      });
      Future.microtask(_fetchServerScans);
    }
  }

  Future<void> _fetchServerScans() async {
    final selectedTask = ref.read(selectedTaskProvider);
    if (selectedTask == null) return;
    await ref
        .read(scanProvider.notifier)
        .fetchFromServer(projectId: selectedTask.id);
  }

  Future<void> _openCamera() async {
    if (!_canUseCamera || cameraOpen) return;
    setState(() {
      cameraOpen = true;
      lastDetected = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _cameraController?.start();
      } catch (_) {
        if (!mounted) return;
        setState(() => cameraOpen = false);
      }
    });
  }

  Future<void> _closeCamera() async {
    if (!cameraOpen) return;
    try {
      await _cameraController?.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      cameraOpen = false;
      torchOn = false;
    });
  }

  void _addBarcode(String value) {
    final v = value.trim();
    if (v.isEmpty) return;

    final selectedTask = ref.read(selectedTaskProvider);
    if (selectedTask == null || !selectedTask.isOpen) {
      setState(() {
        _feedbackError = true;
        _feedbackMessage = 'Нээлттэй task сонгоно уу';
      });
      return;
    }

    final scanNotifier = ref.read(scanProvider.notifier);
    if (!scanNotifier.shouldAccept(v)) {
      AudioService.instance.playError();
      setState(() {
        _feedbackError = true;
        _feedbackMessage = 'Давхардсан scan алгасагдлаа';
      });
      return;
    }

    final authState = ref.read(authStateProvider);
    scanNotifier.addScan(
      taskId: selectedTask.id,
      taskName: selectedTask.name,
      barcodeValue: v,
      username: authState.user?['username'] as String?,
    );
    ref.read(tasksProvider.notifier).incrementScanCount(selectedTask.id);

    AudioService.instance.playBeep();
    setState(() {
      _lastAdded = v;
      _feedbackError = false;
      _feedbackMessage = 'Шинэ scan queue-д орлоо';
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!cameraOpen) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    final now = DateTime.now();
    if (lastDetected == raw &&
        lastDetectedAt != null &&
        now.difference(lastDetectedAt!).inMilliseconds < 800) {
      return;
    }
    lastDetected = raw;
    lastDetectedAt = now;
    _addBarcode(raw);
  }

  void _onManualSubmit() {
    final v = _manualController.text.trim();
    if (v.isEmpty) return;
    _addBarcode(v);
    _manualController.clear();
    _manualFocus.requestFocus();
  }

  @override
  void dispose() {
    _webRefreshTimer?.cancel();
    _cameraController?.dispose();
    _manualController.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedTask = ref.watch(selectedTaskProvider);
    final tasks = ref.watch(tasksProvider);
    final openTasks = tasks.where((t) => t.isOpen).toList();
    final scans = ref.watch(scanProvider);
    final pendingCount = selectedTask != null
        ? scans.where((s) => s.projectId == selectedTask.id && !s.synced).length
        : scans.where((s) => !s.synced).length;
    final canScan = selectedTask != null && selectedTask.isOpen;
    final taskScans = selectedTask != null
        ? scans.where((s) => s.projectId == selectedTask.id).toList()
        : const [];
    final syncedCount = selectedTask != null
        ? scans.where((s) => s.projectId == selectedTask.id && s.synced).length
        : scans.where((s) => s.synced).length;
    final latestSessionScan = taskScans.isEmpty
        ? null
        : taskScans
            .map((scan) => scan.scannedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Workspace'),
        actions: [
          PopupMenuButton<TaskInfo>(
            tooltip: S.selectTask,
            icon: const Icon(Icons.task_alt),
            onSelected: (t) =>
                ref.read(selectedTaskProvider.notifier).state = t,
            itemBuilder: (_) => [
              if (openTasks.isEmpty)
                const PopupMenuItem(
                  enabled: false,
                  child: Text('Нээлттэй даалгавар байхгүй'),
                ),
              ...openTasks.map((t) => PopupMenuItem(
                    value: t,
                    child: Text(t.name),
                  )),
            ],
          ),
          if (_canUseCamera && cameraOpen)
            IconButton(
              tooltip: S.torch,
              onPressed: () async {
                await _cameraController?.toggleTorch();
                setState(() => torchOn = !torchOn);
              },
              icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
            ),
          IconButton(
            tooltip: S.logout,
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE9F5F0),
              scheme.surface,
              const Color(0xFFF3EEE2),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          children: [
            AppReveal(
              child: _scanHero(
                context,
                selectedTask: selectedTask,
                pendingCount: pendingCount,
                openTaskCount: openTasks.length,
                canScan: canScan,
                latestSessionScan: latestSessionScan,
              ),
            ),
            const SizedBox(height: 18),
            AppReveal(
              child: _quickStats(
                context,
                taskScans.length,
                pendingCount,
                syncedCount,
                canScan,
              ),
            ),
            const SizedBox(height: 18),
            AppReveal(
              child: _sessionStrip(
                  context, selectedTask, pendingCount, syncedCount),
            ),
            const SizedBox(height: 18),
            AppReveal(child: _manualInputCard(context, canScan)),
            const SizedBox(height: 18),
            AppReveal(
              child: _canUseCamera
                  ? _cameraPanel(context, canScan)
                  : _webPanel(context, taskScans, selectedTask, canScan),
            ),
          ],
        ),
      ),
      bottomNavigationBar: pendingCount > 0
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A23),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(28),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem, color: Color(0xFFFFC857)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pendingCount pending scans',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          Text(
                            'Сервер рүү илгээгээгүй өгөгдөл байна.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final result =
                            await ref.read(scanProvider.notifier).syncPending();
                        if (!mounted) return;
                        if (result.sent > 0) {
                          AudioService.instance.playSuccess();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${result.sent} pending scan амжилттай илгээгдлээ'),
                            ),
                          );
                        } else if (result.failed > 0) {
                          AudioService.instance.playError();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${result.failed} pending scan илгээж чадсангүй'),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC857),
                        foregroundColor: Colors.black87,
                      ),
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(S.sendAll),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _scanHero(
    BuildContext context, {
    required TaskInfo? selectedTask,
    required int pendingCount,
    required int openTaskCount,
    required bool canScan,
    required DateTime? latestSessionScan,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F6C5A), Color(0xFF163C60)],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(42),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scanner cockpit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            selectedTask?.name ?? 'Даалгавар сонгож урсгалаа эхлүүлнэ үү',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontSize: selectedTask == null ? 30 : 34,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroTag(context, Icons.task_alt, '$openTaskCount open tasks'),
              _heroTag(context, Icons.pending_actions, '$pendingCount pending'),
              _heroTag(
                context,
                canScan ? Icons.check_circle : Icons.pause_circle,
                canScan ? 'Скан хийхэд бэлэн' : 'Task сонгож хүлээж байна',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            latestSessionScan == null
                ? 'Сүүлийн scan хараахан алга.'
                : 'Сүүлийн session scan: ${_formatDateTime(latestSessionScan)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }

  Widget _quickStats(
    BuildContext context,
    int scannedCount,
    int pendingCount,
    int syncedCount,
    bool canScan,
  ) {
    return Row(
      children: [
        Expanded(
          child: _opsStat(
            context,
            icon: Icons.qr_code_2,
            label: 'Session scan',
            value: '$scannedCount',
            accent: const Color(0xFF0F6C5A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _opsStat(
            context,
            icon: Icons.cloud_upload_outlined,
            label: 'Pending sync',
            value: '$pendingCount',
            accent: pendingCount > 0
                ? const Color(0xFFB87416)
                : const Color(0xFF1A3A5F),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _opsStat(
            context,
            icon: Icons.cloud_done_outlined,
            label: 'Synced',
            value: '$syncedCount',
            accent: const Color(0xFF1A3A5F),
          ),
        ),
      ],
    );
  }

  Widget _sessionStrip(
    BuildContext context,
    TaskInfo? selectedTask,
    int pendingCount,
    int syncedCount,
  ) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppInfoPill(
                icon: Icons.task_alt,
                label: selectedTask?.name ?? 'Task сонгоогүй',
              ),
              AppInfoPill(
                icon: Icons.cloud_upload,
                label: '$pendingCount pending',
              ),
              AppInfoPill(
                icon: Icons.cloud_done,
                label: '$syncedCount synced',
              ),
            ],
          ),
          if (_feedbackMessage != null) ...[
            const SizedBox(height: 14),
            AppInlineBanner(
              message: _feedbackMessage!,
              error: _feedbackError,
              onDismiss: () => setState(() => _feedbackMessage = null),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                avatar: const Icon(Icons.sync_problem, size: 16),
                label: const Text('Pending queue'),
                onPressed: () => context.go('/pending'),
              ),
              ActionChip(
                avatar: const Icon(Icons.history, size: 16),
                label: const Text('History'),
                onPressed: () => context.go('/history'),
              ),
            ],
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

  Widget _opsStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _manualInputCard(BuildContext context, bool canScan) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manual capture', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Камергүй үед эсвэл fallback горимд barcode-г гараар оруулна.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _manualController,
            focusNode: _manualFocus,
            enabled: canScan,
            cursorColor: scheme.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
            decoration: InputDecoration(
              labelText: 'Баркод оруулах',
              hintText: 'Enter дарж бүртгэнэ',
              prefixIcon: const Icon(Icons.keyboard_command_key),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                onPressed: canScan ? _onManualSubmit : null,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: canScan ? (_) => _onManualSubmit() : null,
          ),
        ],
      ),
    );
  }

  Widget _cameraPanel(BuildContext context, bool canScan) {
    return Container(
      height: 460,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1713),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraOpen && _cameraController != null)
              MobileScanner(
                controller: _cameraController!,
                onDetect: _onDetect,
              )
            else
              InkWell(
                onTap: canScan ? _openCamera : null,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [Color(0xFF1A3028), Color(0xFF09100D)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.center_focus_strong,
                            size: 72, color: Colors.white70),
                        const SizedBox(height: 14),
                        Text(
                          canScan
                              ? 'Tap to arm scanner'
                              : 'Даалгавар сонгоно уу',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canScan
                              ? 'Live capture эхлүүлэхийн тулд камер нээнэ үү.'
                              : 'Нээлттэй даалгаваргүй үед scan идэвхгүй.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Row(
                children: [
                  _overlayBadge(
                    icon: Icons.radar,
                    label: cameraOpen ? 'Scanner armed' : 'Camera standby',
                  ),
                  const Spacer(),
                  if (cameraOpen)
                    IconButton(
                      onPressed: _closeCamera,
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
            if (_lastAdded != null)
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F8B68).withAlpha(235),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Captured',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                            Text(
                              _lastAdded!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _webPanel(
    BuildContext context,
    List<dynamic> taskScans,
    TaskInfo? selectedTask,
    bool canScan,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: taskScans.isEmpty
          ? Column(
              children: [
                const SizedBox(height: 16),
                Icon(Icons.qr_code_scanner,
                    size: 56, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 14),
                Text(
                  selectedTask == null
                      ? 'Даалгавар сонгоно уу'
                      : 'Баркод оруулна уу',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  canScan
                      ? 'Эндээс оруулсан баркодууд real-time жагсаалтаар харагдана.'
                      : 'Task сонгоогүй үед capture идэвхгүй байна.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live queue',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...taskScans.map((s) {
                  final dt = s.scannedAt;
                  final time =
                      '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withAlpha(120),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withAlpha(180),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              time.substring(0, 2),
                              style: Theme.of(context).textTheme.labelLarge,
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
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(time,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(scanProvider.notifier).removeScan(s.id),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _heroTag(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _overlayBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
