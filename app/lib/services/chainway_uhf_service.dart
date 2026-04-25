import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A single tag observation coming from the Chainway UHF reader.
@immutable
class UhfTag {
  const UhfTag({
    required this.epc,
    this.rssi = '',
    this.tid,
    this.user,
    this.reserved,
    this.count = 1,
    this.phase,
  });

  final String epc;
  final String rssi;
  final String? tid;
  final String? user;
  final String? reserved;
  final int count;
  final num? phase;

  factory UhfTag.fromMap(Map<dynamic, dynamic> map) {
    return UhfTag(
      epc: (map['epc'] ?? '').toString(),
      rssi: (map['rssi'] ?? '').toString(),
      tid: map['tid']?.toString(),
      user: map['user']?.toString(),
      reserved: map['reserved']?.toString(),
      count: (map['count'] is int)
          ? map['count'] as int
          : int.tryParse('${map['count']}') ?? 1,
      phase: map['phase'] is num ? map['phase'] as num : null,
    );
  }
}

enum UhfKeyAction { down, up }

@immutable
class UhfKeyEvent {
  const UhfKeyEvent({required this.keyCode, required this.action});
  final int keyCode;
  final UhfKeyAction action;
}

/// Thin Dart wrapper around the Chainway UHF Android plugin living in
/// `android/app/src/main/kotlin/.../ChainwayUhfPlugin.kt`.
///
/// Non-Android platforms (web / iOS / desktop) degrade to a no-op: every
/// call resolves cleanly with a "not supported" response so UI code can
/// render a disabled state without branching.
class ChainwayUhfService {
  ChainwayUhfService._();
  static final ChainwayUhfService instance = ChainwayUhfService._();

  static const _method = MethodChannel('chainway_uhf/method');
  static const _events = EventChannel('chainway_uhf/events');

  final _tagController = StreamController<UhfTag>.broadcast();
  final _keyController = StreamController<UhfKeyEvent>.broadcast();

  StreamSubscription<dynamic>? _eventSub;
  bool _initialized = false;
  bool _listening = false;
  bool _inventoryRunning = false;

  /// Stream of realtime tag reads while inventory is active.
  Stream<UhfTag> get tagStream => _tagController.stream;

  /// Stream of hardware scan-trigger events (Chainway side buttons).
  Stream<UhfKeyEvent> get keyStream => _keyController.stream;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isInventoryRunning => _inventoryRunning;
  bool get isInitialized => _initialized;

  /// Returns true if the Chainway DeviceAPI classes are available on this build.
  Future<bool> isSupported() async {
    if (!isAndroid) return false;
    try {
      final ok = await _method.invokeMethod<bool>('isSupported');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureListening() async {
    if (_listening) return;
    _listening = true;
    _eventSub = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final type = event['type']?.toString();
          if (type == 'tag') {
            _tagController.add(UhfTag.fromMap(event));
          } else if (type == 'key') {
            final code = (event['keyCode'] is int)
                ? event['keyCode'] as int
                : int.tryParse('${event['keyCode']}') ?? 0;
            final actionRaw = event['action']?.toString();
            final action = actionRaw == 'down' ? UhfKeyAction.down : UhfKeyAction.up;
            _keyController.add(UhfKeyEvent(keyCode: code, action: action));
          }
        }
      },
      onError: (Object err, StackTrace st) {
        debugPrint('[ChainwayUhf] event stream error: $err');
      },
    );
  }

  /// Initializes the underlying Chainway reader. Safe to call multiple times.
  Future<void> init() async {
    if (!isAndroid) {
      throw StateError('Chainway UHF is only supported on Android (C5 device).');
    }
    await _ensureListening();
    if (_initialized) return;
    final ok = await _method.invokeMethod<bool>('init');
    _initialized = ok ?? false;
    if (!_initialized) {
      throw StateError('Chainway UHF init failed');
    }
  }

  Future<void> free() async {
    if (!isAndroid) return;
    try {
      await _method.invokeMethod<void>('free');
    } catch (_) {}
    _initialized = false;
    _inventoryRunning = false;
  }

  /// Starts continuous inventory. Tags will be emitted on [tagStream].
  Future<void> startInventory() async {
    if (!isAndroid) return;
    if (!_initialized) {
      await init();
    }
    await _ensureListening();
    final ok = await _method.invokeMethod<bool>('startInventory');
    _inventoryRunning = ok ?? false;
  }

  Future<void> stopInventory() async {
    if (!isAndroid) return;
    try {
      await _method.invokeMethod<bool>('stopInventory');
    } finally {
      _inventoryRunning = false;
    }
  }

  /// Single-shot read. Returns null if no tag was detected.
  Future<UhfTag?> singleRead() async {
    if (!isAndroid) return null;
    if (!_initialized) {
      await init();
    }
    final raw = await _method.invokeMethod<Map<dynamic, dynamic>?>('singleRead');
    if (raw == null) return null;
    return UhfTag.fromMap(raw);
  }

  /// RFID transmit power, accepted range 5-33 dBm depending on device.
  Future<bool> setPower(int power) async {
    if (!isAndroid) return false;
    final ok = await _method.invokeMethod<bool>(
      'setPower',
      <String, dynamic>{'power': power},
    );
    return ok ?? false;
  }

  Future<int?> getPower() async {
    if (!isAndroid) return null;
    return _method.invokeMethod<int>('getPower');
  }

  Future<({String software, String hardware})?> getVersion() async {
    if (!isAndroid) return null;
    final raw = await _method.invokeMethod<Map<dynamic, dynamic>?>('getVersion');
    if (raw == null) return null;
    return (
      software: (raw['software'] ?? '').toString(),
      hardware: (raw['hardware'] ?? '').toString(),
    );
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _listening = false;
    await _tagController.close();
    await _keyController.close();
  }
}
