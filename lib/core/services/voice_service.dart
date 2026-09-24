import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

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