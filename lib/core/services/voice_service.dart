import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/material_models.dart';

/// Runs on-device OCR using Google ML Kit's text recognizer.
///
/// Why on-device OCR instead of sending the raw image straight to the LLM:
/// - It's free and instant (no network round trip for the pixel data).
/// - It gives us a confidence signal (via block/line geometry) we can use
///   to flag low-quality captures *before* burning an LLM call on them.
/// - The extracted text is what populates the "editable preview" step from
///   the README, so users can fix OCR noise (misread dates, smudged digits)
///   before it ever reaches the LLM — this is what keeps JSON parse/field
///   errors low downstream.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extracts text from a photo of a syllabus, notes page, or slide.
  Future<RawMaterial> extractFromImage(
    File imageFile, {
    String? courseId,
  }) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText result = await _recognizer.processImage(inputImage);

    final confidence = _estimateConfidence(result);

    return RawMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      source: MaterialSource.photo,
      courseId: courseId,
      extractedText: result.text,
      confidence: confidence,
      capturedAt: DateTime.now(),
    );
  }

  /// ML Kit doesn't return a single scalar confidence, so we derive a
  /// proxy from structural signals:
  ///  - fraction of lines that look like "real" text (length, alnum ratio)
  ///  - overall text density relative to the number of detected blocks
  /// This is intentionally simple and cheap; it only needs to be good
  /// enough to decide "show a 'review this carefully' banner or not".
  double _estimateConfidence(RecognizedText result) {
    final lines = result.blocks.expand((b) => b.lines).toList();
    if (lines.isEmpty) return 0.0;

    int plausibleLines = 0;
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final alnum = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
      final ratio = alnum / max(text.length, 1);
      // A line that's mostly letters/numbers and has some real length
      // is "plausible"; lines that are mostly punctuation/noise aren't.
      if (ratio > 0.4 && text.length >= 3) plausibleLines++;
    }

    return (plausibleLines / lines.length).clamp(0.0, 1.0);
  }

  void dispose() {
    _recognizer.close();
  }
}

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('Speech status: $status'),
    );
    return _initialized;
  }

  Future<RawMaterial> listenAndTranscribe({
    String? courseId,
    void Function(String partialText)? onPartialResult,
    Duration maxDuration = const Duration(minutes: 3),
  }) async {
    if (!await initialize()) {
      throw StateError(
        'Speech recognition is unavailable. Check microphone permission and device support.',
      );
    }

    final completer = _TranscriptCompleter();
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onPartialResult?.call(result.recognizedWords);
        if (result.finalResult) {
          completer.complete(result.recognizedWords, result.confidence);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: maxDuration,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      ),
    );

    final transcript = await completer.future;
    await _speech.stop();
    return RawMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      source: MaterialSource.voice,
      courseId: courseId,
      extractedText: transcript.text,
      confidence: transcript.confidence > 0 ? transcript.confidence : 0.5,
      capturedAt: DateTime.now(),
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
  bool get isListening => _speech.isListening;
}

class _TranscriptResult {
  const _TranscriptResult(this.text, this.confidence);

  final String text;
  final double confidence;
}

class _TranscriptCompleter {
  final Completer<_TranscriptResult> _completer =
      Completer<_TranscriptResult>();

  void complete(String text, double confidence) {
    if (!_completer.isCompleted) {
      _completer.complete(_TranscriptResult(text, confidence));
    }
  }

  Future<_TranscriptResult> get future => _completer.future;
}
