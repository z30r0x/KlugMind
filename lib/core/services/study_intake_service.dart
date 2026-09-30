// lib/core/services/study_intake_service.dart
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'llm_service.dart';
import 'on_device_llm_service.dart';
import 'voice_service.dart' show OcrService;

/// Facade for Notes intake: PDF / photo / typed text -> RawMaterial -> LLM.
/// Dependencies are lazy so subclasses/tests never touch platform channels.
class StudyIntakeService {
  StudyIntakeService({LlmService? llm, OcrService? ocr})
      : _llmOverride = llm,
        _ocrOverride = ocr;

  static const int maxChars = 12000;
  static const int maxPdfBytes = 15 * 1024 * 1024;

  /// A 0.5B on-device model has a ~1280-token window. Prompt schema
  /// (~350 tokens) + input + output must fit, so cap the input hard.
  static const int onDeviceMaxChars = 1500;

  final LlmService? _llmOverride;
  final OcrService? _ocrOverride;
  LlmService? _llmCache;
  OcrService? _ocrCache;

  LlmService get _llm => _llmOverride ?? (_llmCache ??= _buildLlm());
  OcrService get _ocr => _ocrOverride ?? (_ocrCache ??= OcrService());

  /// Non-secret config only; .env ships inside the APK/IPA.
  /// OLLAMA_BASE_URL set -> Ollama (development). Otherwise -> on-device.
  static LlmService _buildLlm() {
    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};
    final url = env['OLLAMA_BASE_URL'];
    if (url != null && url.isNotEmpty) {
      return LlmService(
          baseUrl: url, model: env['OLLAMA_MODEL'] ?? 'qwen2.5:3b');
    }
    return OnDeviceLlmService(
      modelUrl: env['MODEL_URL'] ?? '',
      modelType: env['MODEL_TYPE'] ?? 'qwen',
    );
  }

  /// Strips control chars (keeps \n, \t), trims, caps length.
  static String sanitize(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'), '')
        .trim();
    return cleaned.length > maxChars ? cleaned.substring(0, maxChars) : cleaned;
  }

  /// Downloads the on-device model if needed; no-op for other backends.
  Future<void> prepareModel({void Function(int percent)? onProgress}) async {
    final l = _llm;
    if (l is OnDeviceLlmService) await l.ensureReady(onProgress: onProgress);
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
    var clean = sanitize(material.extractedText);
    if (clean.isEmpty) {
      throw const FormatException('Add notes, a PDF, or a photo first.');
    }
    final small = _llm is OnDeviceLlmService;
    if (small && clean.length > onDeviceMaxChars) {
      clean = clean.substring(0, onDeviceMaxChars);
    }
    return _llm.structureMaterial(
      material.copyWith(extractedText: clean),
      flashcardCount: small ? 5 : 10,
      quizItemCount: small ? 3 : 5,
    );
  }

  void dispose() {
    _ocrCache?.dispose();
    final l = _llmCache;
    if (l is OnDeviceLlmService) l.dispose();
  }
}