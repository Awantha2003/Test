import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Listens for the child's secret safe-word and fires [onTriggered].
///
/// Privacy: recognition runs on-device where the OS supports it and no audio is
/// stored or uploaded. It only runs while Guard Mode is open on screen, because both
/// iOS and Android stop microphone access for apps in the background.
class VoiceGuard {
  VoiceGuard({required this.safeWord, required this.onTriggered, this.onStatus});

  final String safeWord;
  final VoidCallback onTriggered;
  final ValueChanged<String>? onStatus;

  final _stt = SpeechToText();
  bool _active = false;
  bool _fired = false;

  bool get active => _active;

  Future<bool> start() async {
    if (safeWord.trim().isEmpty) return false;
    final ok = await _stt.initialize(
      onStatus: (s) {
        onStatus?.call(s);
        // The OS ends each session after a pause; restart while guard is active.
        if (_active && (s == 'done' || s == 'notListening')) _restartSoon();
      },
      onError: (e) {
        if (_active) _restartSoon();
      },
    );
    if (!ok) return false;
    _active = true;
    _fired = false;
    await _listen();
    return true;
  }

  Future<void> stop() async {
    _active = false;
    await _stt.stop();
  }

  Timer? _restart;
  void _restartSoon() {
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 600), () {
      if (_active && !_stt.isListening) _listen();
    });
  }

  Future<void> _listen() => _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          onDevice: false, // fall back to the OS recogniser when no offline model exists
          cancelOnError: false,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 8),
        ),
      );

  void _onResult(SpeechRecognitionResult r) {
    if (_fired) return;
    if (matchesSafeWord(r.recognizedWords, safeWord)) {
      _fired = true;
      onTriggered();
    }
  }

  /// Case- and punctuation-insensitive whole-phrase match. Saying it twice is not needed.
  @visibleForTesting
  static bool matchesSafeWord(String heard, String safeWord) {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r"[^\p{L}\p{N}\s]", unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final h = ' ${norm(heard)} ';
    final w = norm(safeWord);
    return w.isNotEmpty && h.contains(' $w ');
  }
}
