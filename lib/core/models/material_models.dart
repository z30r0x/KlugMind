/// Core data models for KlugMind's material intake pipeline.
///
/// These mirror the "Core Data Models" section of the README:
/// Course, Assignment/Exam, StudyTask, Material/Note, Flashcard/QuizItem.
/// Only the fields relevant to AI ingestion (OCR + voice + LLM structuring)
/// are included here; persistence-layer fields (Hive/Supabase ids etc.)
/// can be layered on top.
library;

/// Where a piece of raw material came from.
enum MaterialSource { photo, pdf, voice, typedText }

/// Raw material captured from the user, before LLM structuring.
class RawMaterial {
  final String id;
  final MaterialSource source;
  final String? courseId;

  /// Plain text after OCR (photo/PDF) or speech-to-text (voice).
  /// This is what gets shown in the "editable preview" step and then
  /// sent to the LLM.
  final String extractedText;

  /// 0.0–1.0 confidence estimate from the extraction engine, used to
  /// decide whether to nudge the user to review the preview more closely.
  final double confidence;

  final DateTime capturedAt;

  const RawMaterial({
    required this.id,
    required this.source,
    required this.extractedText,
    required this.confidence,
    required this.capturedAt,
    this.courseId,
  });

  RawMaterial copyWith({String? extractedText, double? confidence}) {
    return RawMaterial(
      id: id,
      source: source,
      courseId: courseId,
      extractedText: extractedText ?? this.extractedText,
      confidence: confidence ?? this.confidence,
      capturedAt: capturedAt,
    );
  }
}

/// One assignment/exam entry as extracted by the LLM from raw material.
class ExtractedAssignment {
  final String title;
  final String type; // "assignment" | "exam" | "quiz" | "project" | ...
  final DateTime? dueDate;
  final double? weight; // grade weighting, e.g. 0.15 for 15%
  final String? notes;

  const ExtractedAssignment({
    required this.title,
    required this.type,
    this.dueDate,
    this.weight,
    this.notes,
  });

  factory ExtractedAssignment.fromJson(Map<String, dynamic> json) {
    return ExtractedAssignment(
      title: json['title'] as String,
      type: json['type'] as String? ?? 'assignment',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'type': type,
        'due_date': dueDate?.toIso8601String(),
        'weight': weight,
        'notes': notes,
      };
}

/// The full structured result of running one RawMaterial through the LLM.
class StructuredExtraction {
  final List<ExtractedAssignment> assignments;
  final List<GeneratedFlashcard> flashcards;
  final List<GeneratedQuizItem> quizItems;

  /// True if the LLM's output failed schema validation on the first pass
  /// and had to go through the fallback repair prompt (see LlmService).
  final bool usedFallbackRepair;

  const StructuredExtraction({
    required this.assignments,
    required this.flashcards,
    required this.quizItems,
    this.usedFallbackRepair = false,
  });

  factory StructuredExtraction.empty() => const StructuredExtraction(
        assignments: [],
        flashcards: [],
        quizItems: [],
      );
}

class GeneratedFlashcard {
  final String question;
  final String answer;
  final String difficulty; // "easy" | "medium" | "hard"

  const GeneratedFlashcard({
    required this.question,
    required this.answer,
    required this.difficulty,
  });

  factory GeneratedFlashcard.fromJson(Map<String, dynamic> json) {
    return GeneratedFlashcard(
      question: json['question'] as String,
      answer: json['answer'] as String,
      difficulty: json['difficulty'] as String? ?? 'medium',
    );
  }
}

class GeneratedQuizItem {
  final String question;
  final List<String> options;
  final int correctOptionIndex;

  const GeneratedQuizItem({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
  });

  factory GeneratedQuizItem.fromJson(Map<String, dynamic> json) {
    return GeneratedQuizItem(
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctOptionIndex: json['correct_option_index'] as int,
    );
  }
}