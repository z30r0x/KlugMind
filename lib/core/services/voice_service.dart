import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/material_models.dart';

/// Runs on-device OCR using Google ML Kit's text recognizer.
/// The extracted text feeds the editable preview step before the LLM call.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<RawMaterial> extractFromImage(
    File imageFile, {
    String? courseId,
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText result = await _recognizer.processImage(inputImage);

    return RawMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      source: MaterialSource.photo,
      courseId: courseId,
      extractedText: result.text,
      confidence: _estimateConfidence(result),
      capturedAt: DateTime.now(),
    );
  }

  /// Proxy confidence: fraction of lines that look like real text.
  double _estimateConfidence(RecognizedText result) {
    final lines = result.blocks.expand((b) => b.lines).toList();
    if (lines.isEmpty) return 0.0;

    int plausibleLines = 0;
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final alnum = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
      final ratio = alnum / max(text.length, 1);
      if (ratio > 0.4 && text.length >= 3) plausibleLines++;
    }
    return (plausibleLines / lines.length).clamp(0.0, 1.0);
  }

  void dispose() {
    _recognizer.close();
  }
}

/// Final speech-to-text output.
class TranscriptResult {
  const TranscriptResult(this.text, this.confidence);

  final String text;
  final double confidence;
}

/// One dictation run. Completes exactly once, from whichever fires first:
/// final result, platform "done" status, error, stop/cancel, or safety timeout.
/// Falls back to the last partial words so a transcript is never lost.
class TranscriptSession {
  final Completer<TranscriptResult> _completer = Completer();
  String _words = '';
  double _confidence = 0;

  Future<TranscriptResult> get future => _completer.future;
  bool get isDone => _completer.isCompleted;

  void update(String words, double confidence) {
    if (words.isNotEmpty) _words = words;
    if (confidence > 0) _confidence = confidence;
  }

  void finish({String? error}) {
    if (_completer.isCompleted) return;
    final text = VoiceService.cleanTranscript(_words);
    if (text.isEmpty) {
      _completer.completeError(
        StateError(
          error == 'error_permission'
              ? 'Microphone permission denied.'
              : 'No speech detected. Try again.',
        ),
      );
      return;
    }
    _completer.complete(TranscriptResult(text, _confidence));
  }
}

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  TranscriptSession? _session;

  /// Collapses whitespace/control chars. Length capping is done downstream
  /// by StudyIntakeService.sanitize.
  static String cleanTranscript(String input) => input
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        _session?.finish(error: error.errorMsg);
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
        // 'done' arrives after the final result; 'notListening' can precede it.
        if (status == 'done') _session?.finish();
      },
    );
    return _initialized;
  }

  /// Listens, then returns the transcript as a [RawMaterial] (source: voice)
  /// ready for the same LLM pipeline as OCR/typed text.
  Future<RawMaterial> listenAndTranscribe({
    String? courseId,
    void Function(String partialText)? onPartialResult,
    Duration maxDuration = const Duration(minutes: 3),
  }) async {
    if (_session != null) throw StateError('Already listening.');
    if (!await initialize()) {
      throw StateError(
        'Speech recognition is unavailable. Check microphone permission and device support.',
      );
    }

    final session = TranscriptSession();
    final pending = session.future..ignore(); // avoid unhandled-error race
    _session = session;
    final watchdog = Timer(
      maxDuration + const Duration(seconds: 10),
      session.finish,
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          session.update(result.recognizedWords, result.confidence);
          onPartialResult?.call(result.recognizedWords);
          if (result.finalResult) session.finish();
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: maxDuration,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
      );

      final transcript = await pending;
      return RawMaterial(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        source: MaterialSource.voice,
        courseId: courseId,
        extractedText: transcript.text,
        confidence: transcript.confidence > 0 ? transcript.confidence : 0.5,
        capturedAt: DateTime.now(),
      );
    } finally {
      watchdog.cancel();
      _session = null;
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  /// Ends listening; the in-flight [listenAndTranscribe] resolves with
  /// whatever was heard.
  Future<void> stop() async {
    await _speech.stop();
    _session?.finish();
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _session?.finish(error: 'cancelled');
  }

  bool get isListening => _speech.isListening;
}