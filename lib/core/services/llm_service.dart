import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:klugmind/core/models/material_models.dart';


/// Turns raw OCR/voice text into structured study data using a hosted LLM
/// (Gemini by default; swap the endpoint/key to point at OpenAI/Groq).
///
/// This is the piece the README calls out under "Hackathon Learning":
/// *"Designed strict JSON schemas for syllabus extraction, reducing JSON
/// parse errors from ~20% to under 1.5% using schema enforcement and
/// fallback repair layers."* The two techniques doing that work are:
///
/// 1. **Structured JSON mode**: we tell the model exactly which keys,
///    types, and enums are allowed, and ask for JSON-only output — no
///    prose, no markdown fences. Constraining the *shape* of the output
///    up front prevents most of the malformed-response class of errors.
/// 2. **Fallback repair pass**: if the first response still doesn't
///    parse (rare, but happens with edge-case handwriting or ambiguous
///    dates), we don't retry blindly — we send the *broken* output back
///    to the model in a second call and ask it specifically to fix it
///    into valid JSON matching the schema. This is cheaper and more
///    reliable than re-running the whole extraction from scratch.
class LlmService {
  final String apiKey;
  final String model;

  LlmService({
    required this.apiKey,
    this.model = 'gemini-2.0-flash',
  });

  Uri get _endpoint => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent?key=$apiKey',
      );

  /// Main entry point: raw text in (from OCR or voice) -> structured
  /// assignments/flashcards/quiz items out.
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

    final rawResponse = await _callModel(prompt);
    final parsed = _tryParseJson(rawResponse);

    if (parsed != null) {
      return _toStructuredExtraction(parsed, usedFallbackRepair: false);
    }

    // First pass failed schema validation -> fallback repair pass.
    final repaired = await _repairJson(rawResponse);
    if (repaired != null) {
      return _toStructuredExtraction(repaired, usedFallbackRepair: true);
    }

    // Both passes failed. Don't fabricate data — surface an empty result
    // so the UI can prompt the user to retry or edit the preview text
    // manually instead of silently losing their material.
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

  Future<String> _callModel(String prompt) async {
    final response = await http.post(
      _endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          // Structured JSON mode: forces the model to emit a JSON object
          // rather than free-form text, which is the single biggest lever
          // for cutting parse errors mentioned in the README.
          'response_mime_type': 'application/json',
          'temperature': 0.2,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'LLM call failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('LLM returned no candidates.');
    }
    final parts = candidates.first['content']['parts'] as List;
    return parts.map((p) => p['text'] as String).join();
  }

  /// Asks the model to fix its own previous output into valid JSON,
  /// rather than re-deriving the extraction from the source text again.
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
    final fixed = await _callModel(repairPrompt);
    return _tryParseJson(fixed);
  }

  Map<String, dynamic>? _tryParseJson(String text) {
    // Defensive strip in case the model wraps output in ```json fences
    // despite instructions not to — cheap and doesn't hurt correct output.
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
      return null; // Parsed but doesn't match schema shape.
    } catch (_) {
      return null;
    }
  }

  StructuredExtraction _toStructuredExtraction(
    Map<String, dynamic> json, {
    required bool usedFallbackRepair,
  }) {
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
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}