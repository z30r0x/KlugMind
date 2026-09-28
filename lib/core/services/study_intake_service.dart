// lib/core/services/study_intake_service.dart
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'llm_service.dart';
import 'voice_service.dart' show OcrService;

/// Facade for Notes intake: PDF / photo / typed text -> RawMaterial -> LLM.
/// Dependencies are lazy so subclasses/tests never touch platform channels.
class StudyIntakeService {
  StudyIntakeService({LlmService? llm, OcrService? ocr})
      : _llmOverride = llm,
        _ocrOverride = ocr;

  static const int maxChars = 12000;
  static const int maxPdfBytes = 15 * 1024 * 1024;

  final LlmService? _llmOverride;
  final OcrService? _ocrOverride;
  LlmService? _llmCache;
  OcrService? _ocrCache;

  LlmService get _llm => _llmOverride ?? (_llmCache ??= _buildLlm());
  OcrService get _ocr => _ocrOverride ?? (_ocrCache ??= OcrService());

  static LlmService _buildLlm() {
    // Non-secret config only; .env ships inside the APK/IPA.
    final url = dotenv.isInitialized ? dotenv.env['OLLAMA_BASE_URL'] : null;
    final model = dotenv.isInitialized ? dotenv.env['OLLAMA_MODEL'] : null;
    if (url == null || url.isEmpty) return LlmService();
    return LlmService(baseUrl: url, model: model ?? 'llama3.2:3b');
  }

  /// Strips control chars (keeps \n, \t), trims, caps length.
  static String sanitize(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
        .trim();
    return cleaned.length > maxChars ? cleaned.substring(0, maxChars) : cleaned;
  }

  Future<RawMaterial> fromPdf(String path, {String? courseId}) async {
    final file = File(path);
    if (await file.length() > maxPdfBytes) {
      throw const FormatException('That PDF is too large (15 MB max).');
    }
    final bytes = await file.readAsBytes();
    String text;
    try {
      final doc = PdfDocument(inputBytes: bytes);
      try {
        text = PdfTextExtractor(doc).extractText();
      } finally {
        doc.dispose();
      }
    } catch (_) {
      throw const FormatException("Couldn't read that PDF.");
    }
    if (text.trim().isEmpty) {
      throw const FormatException(
          'No selectable text in this PDF. Try taking a photo instead.');
    }
    return RawMaterial(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      source: MaterialSource.pdf,
      courseId: courseId,
      extractedText: text,
      confidence: 1.0,
      capturedAt: DateTime.now(),
    );
  }

  Future<RawMaterial> fromPhoto(File image) async {
    final raw = await _ocr.extractFromImage(image);
    if (raw.extractedText.trim().isEmpty) {
      throw const FormatException(
          'No text found in the photo. Retake it in better light.');
    }
    return raw;
  }

  Future<StructuredExtraction> analyze(RawMaterial material) {
    final clean = sanitize(material.extractedText);
    if (clean.isEmpty) {
      throw const FormatException('Add notes, a PDF, or a photo first.');
    }
    return _llm.structureMaterial(material.copyWith(extractedText: clean));
  }

  void dispose() => _ocrCache?.dispose();
}