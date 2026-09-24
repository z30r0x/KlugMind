import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import '../models/material_models.dart';

/// Handles voice capture for two KlugMind use cases:
///  1. Dictating study material ("read your notes out loud" as an
///     alternative to photographing them).
///  2. Fast task input for the "I Fell Behind" re-planning flow
///     ("I finished chapter 3 but skipped the practice problems").
///
/// Uses `speech_to_text`, which wraps the platform's native on-device
/// speech engine (iOS Speech framework / Android SpeechRecognizer).
/// That keeps voice capture free, low-latency, and offline-capable on
/// most modern devices — consistent with the OCR service's approach of
/// doing extraction on-device and reserving the network call for the
/// LLM structuring step.
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) => print('Speech error: ${e.errorMsg}'),
      onStatus: (status) => print('Speech status: $status'),
    );
    return _initialized;
  }

  /// Starts listening and streams partial transcripts via [onPartialResult],
  /// resolving with the final RawMaterial once the user stops speaking
  /// (or [maxDuration] elapses).
  Future<RawMaterial> listenAndTranscribe({
    String? courseId,
    void Function(String partialText)? onPartialResult,
    Duration maxDuration = const Duration(minutes: 3),
  }) async {
    final ok = await initialize();
    if (!ok) {
      throw StateError(
        'Speech recognition unavailable (permissions denied or '
        'unsupported device).',
      );
    }

    final completer = _TranscriptCompleter();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onPartialResult?.call(result.recognizedWords);
        if (result.finalResult) {
          completer.complete(
            result.recognizedWords,
            result.confidence, // 0.0–1.0, provided natively on Android;
            // iOS often returns 1.0 flat — see note in RawMaterial docs.
          );
        }
      },
      listenFor: maxDuration,
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );

    final transcriptResult = await completer.future;
    await _speech.stop();

    return RawMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      source: MaterialSource.voice,
      courseId: courseId,
      extractedText: transcriptResult.text,
      // Native confidence is unreliable cross-platform; floor it at 0.5
      // so voice input still gets *some* "please review" treatment in UI
      // rather than being trusted as blindly as a clean OCR read.
      confidence:
          transcriptResult.confidence > 0 ? transcriptResult.confidence : 0.5,
      capturedAt: DateTime.now(),
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
  bool get isListening => _speech.isListening;
}

class _TranscriptResult {
  final String text;
  final double confidence;
  _TranscriptResult(this.text, this.confidence);
}

/// Small helper so we can `await` a single final result out of the
/// callback-based speech_to_text API without pulling in a stream
/// controller for what is fundamentally a one-shot value.
class _TranscriptCompleter {
  final _completer = Completer<_TranscriptResult>();

  void complete(String text, double confidence) {
    if (!_completer.isCompleted) {
      _completer.complete(_TranscriptResult(text, confidence));
    }
  }

  Future<_TranscriptResult> get future => _completer.future;
}