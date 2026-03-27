
import 'dart:async';
import 'package:flutter/foundation.dart';

class ColorTapTimer {
  final int duration;
  final Function(int) onTick;
  final VoidCallback onComplete;

  Timer? _timer;
  int _remainingSeconds;
  bool _isRunning = false;

  ColorTapTimer({
    required this.duration,
    required this.onTick,
    required this.onComplete,
  }) : _remainingSeconds = duration;

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _remainingSeconds = duration;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        onTick(_remainingSeconds);
      } else {
        stop();
        onComplete();
      }
    });
  }

  void pause() {
    _isRunning = false;
    _timer?.cancel();
  }

  void resume() {
    if (!_isRunning && _remainingSeconds > 0) {
      start();
    }
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
  }

  void reset() {
    stop();
    _remainingSeconds = duration;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  // Get progress as percentage (0.0 to 1.0)
  double get progress {
    return duration > 0 ? (_remainingSeconds / duration) : 0.0;
  }

  // Get elapsed time
  int get elapsedSeconds {
    return duration - _remainingSeconds;
  }

  // Format time as MM:SS
  String get formattedTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
