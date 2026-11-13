import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Layanan Audio & Haptic Feedback khusus pemindai Barcode Kasir POS
class ScannerFeedbackService {
  static const MethodChannel _channel = MethodChannel('com.garudatel.ipay/scanner_feedback');

  /// Mainkan bunyi BEEP pemindai kasir retail + getaran mantap saat scan berhasil
  static Future<void> playScanSuccess() async {
    try {
      // 1. Haptic Feedback (Getaran fisik HP)
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[ScannerFeedback] Haptic error: $e');
    }

    try {
      // 2. Audio Tone via Native Android ToneGenerator
      final ok = await _channel.invokeMethod<bool>('playBeep');
      if (ok != true) {
        // Fallback jika bukan di Android atau plugin gagal
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Mainkan bunyi peringatan + getaran ganda jika barcode tidak ditemukan
  static Future<void> playScanError() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('[ScannerFeedback] Haptic error: $e');
    }

    try {
      final ok = await _channel.invokeMethod<bool>('playErrorBeep');
      if (ok != true) {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
