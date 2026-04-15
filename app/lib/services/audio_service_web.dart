import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  void _playTone({double frequency = 1000, int durationMs = 120, String type = 'sine'}) {
    try {
      final ctx = web.AudioContext();
      final oscillator = ctx.createOscillator();
      final gain = ctx.createGain();

      oscillator.type = type;
      oscillator.frequency.value = frequency;
      gain.gain.value = 0.3;

      oscillator.connect(gain);
      gain.connect(ctx.destination);

      oscillator.start();
      final stopTime = ctx.currentTime + (durationMs / 1000.0);
      oscillator.stop(stopTime);
    } catch (e) {
      debugPrint('AudioService web: $e');
    }
  }

  Future<void> playBeep() async {
    _playTone(frequency: 1200, durationMs: 100);
  }

  Future<void> playSuccess() async {
    _playTone(frequency: 800, durationMs: 80);
    await Future.delayed(const Duration(milliseconds: 100));
    _playTone(frequency: 1200, durationMs: 120);
  }

  Future<void> playError() async {
    _playTone(frequency: 400, durationMs: 200, type: 'square');
  }

  void dispose() {}
}
