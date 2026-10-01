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

  static final RegExp _datePattern = RegExp(
    r'\b(?:(\d{1,2})(?:st|nd|rd|th)?\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)(?:,?\s+(\d{4}))?|(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?|\b(\d{4})-(\d{1,2})-(\d{1,2}))\b',
    caseSensitive: false,
  );
  static final RegExp _eventPattern = RegExp(
    r'\b(exam|midterm|final|test|quiz|assignment|homework|project|paper|essay)\b',
    caseSensitive: false,
  );

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
        baseUrl: url,
        model: env['OLLAMA_MODEL'] ?? 'qwen2.5:3b',
      );
    }
    return OnDeviceLlmService(
      modelUrl: env['MODEL_URL'] ?? '',
      modelType: env['MODEL_TYPE'] ?? 'qwen',
    );
  }

  /// Strips control chars (keeps \n, \t), trims, caps length.
  static String sanitize(String input) {
    final cleaned = input
        .replaceAll(
          RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
          '',
        )
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
        'No selectable text in this PDF. Try taking a photo instead.',
      );
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
        'No text found in the photo. Retake it in better light.',
      );
    }
    return raw;
  }

  Future<StructuredExtraction> analyze(RawMaterial material) async {
    var clean = sanitize(material.extractedText);
    if (clean.isEmpty) {
      throw const FormatException('Add notes, a PDF, or a photo first.');
    }
    final small = _llm is OnDeviceLlmService;
    if (small && clean.length > onDeviceMaxChars) {
      clean = clean.substring(0, onDeviceMaxChars);
    }
    final extraction = await _llm.structureMaterial(
      material.copyWith(extractedText: clean),
      flashcardCount: small ? 5 : 10,
      quizItemCount: small ? 3 : 5,
    );
    final detected = _extractDatedEvents(clean);
    if (detected.isEmpty) return extraction;

    final assignments = [...extraction.assignments];
    for (final event in detected) {
      final duplicate = assignments.any((assignment) {
        final existingDate = assignment.dueDate;
        final eventDate = event.dueDate!;
        final existingTitle = assignment.title.toLowerCase().trim();
        final eventTitle = event.title.toLowerCase().trim();
        return assignment.type == event.type &&
            existingDate != null &&
            existingDate.year == eventDate.year &&
            existingDate.month == eventDate.month &&
            existingDate.day == eventDate.day &&
            (existingTitle == eventTitle ||
                existingTitle.contains(eventTitle) ||
                eventTitle.contains(existingTitle));
      });
      if (!duplicate) assignments.add(event);
    }

    return StructuredExtraction(
      assignments: assignments,
      flashcards: extraction.flashcards,
      quizItems: extraction.quizItems,
      usedFallbackRepair: extraction.usedFallbackRepair,
    );
  }

  static List<ExtractedAssignment> _extractDatedEvents(String text) {
    final now = DateTime.now();
    final events = <ExtractedAssignment>[];
    for (final dateMatch in _datePattern.allMatches(text)) {
      final dueDate = _dateFromMatch(dateMatch, now);
      if (dueDate == null) continue;

      final separators = RegExp(
        r'[\n.!?]',
      ).allMatches(text.substring(0, dateMatch.start)).toList();
      final contextStart = separators.isEmpty ? 0 : separators.last.end;
      final afterDate = text.substring(dateMatch.end);
      final sentenceEnd = RegExp(r'[\n.!?]').firstMatch(afterDate);
      final contextEnd = sentenceEnd == null
          ? text.length
          : dateMatch.end + sentenceEnd.start;
      final context = text.substring(contextStart, contextEnd);
      final eventMatch = _eventPattern.firstMatch(context);
      if (eventMatch == null) continue;

      final keyword = eventMatch.group(0)!.toLowerCase();
      final type = switch (keyword) {
        'exam' || 'midterm' || 'final' || 'test' => 'exam',
        'quiz' => 'quiz',
        'project' => 'project',
        _ => 'assignment',
      };

      final phrase = text.substring(contextStart, dateMatch.start);
      final title = phrase
          .replaceAll(
            RegExp(
              r'\b(on|due(?:\s+on)?|by|scheduled\s+for|for)\s*$',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(_eventPattern, ' ')
          .replaceAll(RegExp(r'[^\w\s&/-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      events.add(
        ExtractedAssignment(
          title: title.isEmpty ? _titleForType(type) : title,
          type: type,
          dueDate: dueDate,
          notes: 'Detected from the source text',
        ),
      );
    }
    return events;
  }

  static DateTime? _dateFromMatch(RegExpMatch match, DateTime now) {
    int day;
    int month;
    int? year;

    if (match.group(1) != null) {
      day = int.parse(match.group(1)!);
      month = _monthNumber(match.group(2)!);
      year = int.tryParse(match.group(3) ?? '');
    } else if (match.group(4) != null) {
      month = _monthNumber(match.group(4)!);
      day = int.parse(match.group(5)!);
      year = int.tryParse(match.group(6) ?? '');
    } else {
      year = int.parse(match.group(7)!);
      month = int.parse(match.group(8)!);
      day = int.parse(match.group(9)!);
    }

    var date = DateTime(year ?? now.year, month, day);
    if (date.month != month || date.day != day) return null;
    if (year == null && date.isBefore(DateTime(now.year, now.month, now.day))) {
      date = DateTime(now.year + 1, month, day);
    }
    return date;
  }

  static int _monthNumber(String month) =>
      switch (month.toLowerCase().substring(0, 3)) {
        'jan' => 1,
        'feb' => 2,
        'mar' => 3,
        'apr' => 4,
        'may' => 5,
        'jun' => 6,
        'jul' => 7,
        'aug' => 8,
        'sep' => 9,
        'oct' => 10,
        'nov' => 11,
        'dec' => 12,
        _ => throw FormatException('Unknown month: $month'),
      };

  static String _titleForType(String type) => switch (type) {
    'exam' => 'Exam',
    'quiz' => 'Quiz',
    'project' => 'Project',
    _ => 'Assignment',
  };

  void dispose() {
    _ocrCache?.dispose();
    final l = _llmCache;
    if (l is OnDeviceLlmService) l.dispose();
  }
}
