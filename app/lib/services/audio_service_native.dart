import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  Future<void> playBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('AudioService: $e');
    }
  }

  Future<void> playSuccess() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('AudioService: $e');
    }
  }

  Future<void> playError() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('AudioService: $e');
    }
  }

  void dispose() {}
}
