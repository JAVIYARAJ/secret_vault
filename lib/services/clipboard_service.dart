import 'dart:async';
import 'package:flutter/services.dart';

class ClipboardService {
  Timer? _clearTimer;
  Duration _clearAfter;
  void Function(int remaining)? onCountdown;
  VoidCallback? onCleared;

  ClipboardService({Duration clearAfter = const Duration(seconds: 30)})
      : _clearAfter = clearAfter;

  void updateDuration(Duration d) => _clearAfter = d;

  Future<void> copyWithAutoClear(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _clearTimer?.cancel();
    
    if (_clearAfter.inSeconds <= 0) return;

    int remaining = _clearAfter.inSeconds;

    _clearTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      onCountdown?.call(remaining);
      if (remaining <= 0) {
        timer.cancel();
        Clipboard.setData(const ClipboardData(text: ''));
        onCleared?.call();
      }
    });
  }

  void cancelAutoClear() => _clearTimer?.cancel();

  void dispose() {
    _clearTimer?.cancel();
  }
}
