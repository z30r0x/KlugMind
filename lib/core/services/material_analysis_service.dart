import 'dart:io';

import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/video_service.dart';

import 'llm_service.dart';
import 'voice_service.dart';

/// Single entry point the UI talks to. Wraps the three-stage pipeline:
///
///   [ Photo / PDF page ] --OcrService--> text --\
///                                                 --> LlmService --> StructuredExtraction
///   [ Voice recording  ] --VoiceService-> text --/
///
/// Both intake paths converge on the same plain-text representation
/// before hitting the LLM, so the extraction schema, prompt, and repair
/// logic are shared regardless of how the material came in. This is the
/// "structured LLM processing" stage from the README's architecture
/// diagram — everything upstream of it (ML Kit, speech_to_text) exists
/// only to turn pixels/audio into text as cheaply and privately as
/// possible before spending an API call.
class MaterialAnalysisService {
  final OcrService _ocr;
  final VoiceService _voice;
  final LlmService _llm;

  MaterialAnalysisService({
    required LlmService llmService,
    OcrService? ocrService,
    VoiceService? voiceService,
  })  : _llm = llmService,
        _ocr = ocrService ?? OcrService(),
        _voice = voiceService ?? VoiceService();

  /// Analyze a photographed syllabus/notes page end to end.
  /// Returns both the raw OCR text (for the editable preview step) and
  /// the structured extraction, so the UI can show the preview first and
  /// let the user confirm/edit before committing to the database.
  Future<(RawMaterial raw, StructuredExtraction structured)>
      analyzePhoto(File imageFile, {String? courseId}) async {
    final raw = await _ocr.extractFromImage(imageFile, courseId: courseId);
    final structured = await _llm.structureMaterial(raw);
    return (raw, structured);
  }

  /// Analyze a voice dictation end to end. [onPartialTranscript] lets the
  /// UI show live captions while the user is still talking.
  Future<(RawMaterial raw, StructuredExtraction structured)> analyzeVoice({
    String? courseId,
    void Function(String partial)? onPartialTranscript,
  }) async {
    final raw = await _voice.listenAndTranscribe(
      courseId: courseId,
      onPartialResult: onPartialTranscript,
    );
    final structured = await _llm.structureMaterial(raw);
    return (raw, structured);
  }

  /// Re-run structuring on text the user has hand-edited in the preview
  /// step (e.g. after fixing OCR noise) without re-running OCR/voice.
  Future<StructuredExtraction> restructureEditedText(
    RawMaterial original,
    String editedText,
  ) {
    final edited = original.copyWith(extractedText: editedText);
    return _llm.structureMaterial(edited);
  }

  void dispose() {
    _ocr.dispose();
  }
}