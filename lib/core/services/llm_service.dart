import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/material_models.dart';

/// Turns raw OCR/voice text into structured study data.
///
/// Prompt, JSON schema, parsing and the fallback repair pass live here and
/// are shared by every backend. Only [generate] differs:
///  - this class: Ollama over HTTP (dev only, needs a laptop on the network)
///  - OnDeviceLlmService: on-device model (release builds)
///
/// Ollama reachability (dev): Android emulator `http://10.0.2.2:11434`,
/// iOS simulator `http://localhost:11434`, physical device: run
/// `OLLAMA_HOST=0.0.0.0 ollama serve` and use the laptop's LAN IP.
class LlmService {
  final String baseUrl;
  final String model;

  LlmService({
    this.baseUrl = 'http://10.0.2.2:11434',
    this.model = 'llama3.2:3b',
  });

  Uri get _endpoint => Uri.parse('$baseUrl/api/generate');

  /// Main entry point: raw text in -> structured assignments/flashcards/quiz.
  Future<StructuredExtraction> structureMaterial(
    RawMaterial material, {
    int flashcardCount = 10,
    int quizItemCount = 5,
  }) async {
    final prompt = _buildExtractionPrompt(
      material,
      flashcardCount: flashcardCount,
      quizItemCount: quizItemCount,
    );

    final rawResponse = await generate(prompt);
    final parsed = _tryParseJson(rawResponse);
    if (parsed != null) {
      final result = _toStructuredExtraction(parsed, usedFallbackRepair: false);
      if (result != null) return result;
    }

    // First pass failed parsing or schema -> fallback repair pass.
    final repaired = await _repairJson(rawResponse);
    if (repaired != null) {
      final result = _toStructuredExtraction(repaired, usedFallbackRepair: true);
      if (result != null) return result;
    }

    // Both passes failed. Don't fabricate data; the UI asks the user to retry.
    return StructuredExtraction.empty();
  }

  String _buildExtractionPrompt(
    RawMaterial material, {
    required int flashcardCount,
    required int quizItemCount,
  }) {
    final sourceLabel = switch (material.source) {
      MaterialSource.photo => 'a photo of a syllabus or notes page',
      MaterialSource.pdf => 'a PDF of course material',
      MaterialSource.voice => 'a spoken dictation, transcribed to text',
      MaterialSource.typedText => 'typed notes',
    };

    return '''
You are a strict JSON extraction engine for a student study-planning app.
The input below came from $sourceLabel and may contain OCR noise or
speech-to-text artifacts (misheard words, missing punctuation). Infer
intent conservatively — do not invent dates, weights, or facts that
aren't clearly implied by the text.

Return ONLY valid JSON matching this exact schema. No markdown fences,
no commentary, no trailing text before or after the JSON object.

{
  "assignments": [
    {
      "title": string,
      "type": "assignment" | "exam" | "quiz" | "project",
      "due_date": string (ISO 8601 date) | null,
      "weight": number (0.0-1.0, fraction of final grade) | null,
      "notes": string | null
    }
  ],
  "flashcards": [
    {
      "question": string,
      "answer": string,
      "difficulty": "easy" | "medium" | "hard"
    }
  ],
  "quiz_items": [
    {
      "question": string,
      "options": [string, string, string, string],
      "correct_option_index": number (0-3)
    }
  ]
}

Rules:
- If no assignments/exams are mentioned, return an empty array for
  "assignments" — do not fabricate any.
- Generate exactly $flashcardCount flashcards and $quizItemCount quiz
  items from the conceptual content, even if there are zero assignments.
- If the source text is too sparse or garbled to extract anything
  meaningful, return empty arrays for all three fields rather than
  guessing.

SOURCE TEXT:
"""
${material.extractedText}
"""
''';
  }

  /// Overridable model call. Default: Ollama HTTP (dev only).
  Future<String> generate(String prompt) async {
    final http.Response response;
    try {
      response = await http
          .post(
            _endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
              'format': 'json',
              'options': {
                'temperature': 0.2,
                // 1024 truncated 10 cards + 5 quiz items -> broken JSON.
                'num_predict': 2048,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on http.ClientException catch (e) {
      throw HttpException(
        'Could not reach Ollama at $baseUrl — is `ollama serve` running '
        'and reachable from this device? ($e)',
      );
    }

    if (response.statusCode != 200) {
      throw HttpException(
        'LLM call failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = body['response'] as String?;
    if (text == null) {
      throw const FormatException('Ollama returned no `response` field.');
    }
    return text;
  }

  /// Asks the model to fix its own previous output into valid JSON.
  Future<Map<String, dynamic>?> _repairJson(String brokenOutput) async {
    final repairPrompt = '''
The following text was supposed to be a single valid JSON object but
failed to parse. Fix it into valid JSON that preserves all the original
data (do not remove or invent fields). Return ONLY the corrected JSON,
nothing else.

BROKEN OUTPUT:
"""
$brokenOutput
"""
''';
    final fixed = await generate(repairPrompt);
    return _tryParseJson(fixed);
  }

  Map<String, dynamic>? _tryParseJson(String text) {
    final cleaned = text
        .trim()
        .replaceAll(RegExp(r'^```json'), '')
        .replaceAll(RegExp(r'^```'), '')
        .replaceAll(RegExp(r'```$'), '')
        .trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('assignments') &&
          decoded.containsKey('flashcards') &&
          decoded.containsKey('quiz_items')) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns null if any item has wrong types/missing fields (common with
  /// small models), so the caller can fall through to the repair pass.
  StructuredExtraction? _toStructuredExtraction(
    Map<String, dynamic> json, {
    required bool usedFallbackRepair,
  }) {
    try {
      final assignments = (json['assignments'] as List? ?? [])
          .map((a) => ExtractedAssignment.fromJson(a as Map<String, dynamic>))
          .toList();
      final flashcards = (json['flashcards'] as List? ?? [])
          .map((f) => GeneratedFlashcard.fromJson(f as Map<String, dynamic>))
          .toList();
      final quizItems = (json['quiz_items'] as List? ?? [])
          .map((q) => GeneratedQuizItem.fromJson(q as Map<String, dynamic>))
          .toList();

      return StructuredExtraction(
        assignments: assignments,
        flashcards: flashcards,
        quizItems: quizItems,
        usedFallbackRepair: usedFallbackRepair,
      );
    } catch (_) {
      return null;
    }
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}