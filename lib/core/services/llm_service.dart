import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/material_models.dart';

/// Turns raw OCR/voice text into structured study data using a **local**
/// LLM served by Ollama (https://ollama.com) — free, no API key, no rate
/// limits, and fast because there's no network hop to a third party.
///
/// This is the piece the README calls out under "Hackathon Learning":
/// *"Designed strict JSON schemas for syllabus extraction, reducing JSON
/// parse errors from ~20% to under 1.5% using schema enforcement and
/// fallback repair layers."* The two techniques doing that work are:
///
/// 1. **Structured JSON mode**: we tell the model exactly which keys,
///    types, and enums are allowed, and ask for JSON-only output — no
///    prose, no markdown fences. Ollama's `"format": "json"` enforces
///    valid-JSON-shaped output at the sampler level (not just via prompt
///    instructions), which is a stronger guarantee than Gemini's MIME-type
///    hint. Constraining the *shape* of the output up front prevents most
///    of the malformed-response class of errors.
/// 2. **Fallback repair pass**: if the first response still doesn't match
///    our schema (rare, but happens with small/quantized local models on
///    edge-case input), we don't retry blindly — we send the *broken*
///    output back to the model in a second call and ask it specifically
///    to fix it into valid JSON matching the schema. This is cheaper and
///    more reliable than re-running the whole extraction from scratch.
///
/// Reachability note: Ollama binds to localhost on the machine it runs on.
/// - Android emulator -> host laptop: use `http://10.0.2.2:11434`
/// - iOS simulator -> host laptop: `http://localhost:11434` works as-is
/// - Physical device: start Ollama with `OLLAMA_HOST=0.0.0.0 ollama serve`
///   and point [baseUrl] at your laptop's LAN IP, e.g.
///   `http://192.168.1.23:11434`. Both devices must share the same Wi-Fi.
class LlmService {
  final String baseUrl;
  final String model;

  LlmService({
    this.baseUrl = 'http://10.0.2.2:11434',
    this.model = 'llama3.2:3b',
  });

  Uri get _endpoint => Uri.parse('$baseUrl/api/generate');

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
              // Ollama's structured-output mode: constrains sampling to
              // valid JSON, not just a prompt-level instruction.
              'format': 'json',
              'options': {
                'temperature': 0.2,
                // Keep local inference snappy on laptop hardware; raise
                // if truncated JSON shows up in practice for long syllabi.
                'num_predict': 1024,
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

  /// Asks the model to fix its own previous output into valid JSON,
  /// rather than re-deriving the extraction from the source text again.
  Future<Map<String, dynamic>?> _repairJson(String brokenOutput) async {
    final repairPrompt =
        '''
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
