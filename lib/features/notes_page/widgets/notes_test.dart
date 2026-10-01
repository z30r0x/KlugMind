// lib/features/notes_page/notes_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/services/llm_service.dart' as llm;
import 'package:klugmind/core/services/study_intake_service.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/notes_page/notes.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';

const _cards = [
  GeneratedFlashcard(
    question: 'What is SN2?',
    answer: 'Bimolecular',
    difficulty: 'medium',
  ),
  GeneratedFlashcard(question: 'Q2', answer: 'A2', difficulty: 'easy'),
];
const _quiz = [
  GeneratedQuizItem(question: 'q', options: ['a', 'b'], correctOptionIndex: 0),
];

class _FakeIntake extends StudyIntakeService {
  _FakeIntake({
    this.completer,
    this.result,
    this.error,
    this.prepare,
    this.prepareError,
  });
  final Completer<StructuredExtraction>? completer;
  final StructuredExtraction? result;
  final Object? error;
  final Completer<void>? prepare;
  final Object? prepareError;
  RawMaterial? last;

  RawMaterial _mk(MaterialSource s, String t, double c) => RawMaterial(
    id: '1',
    source: s,
    extractedText: t,
    confidence: c,
    capturedAt: DateTime(2026),
  );

  // Must be overridden: the real one would touch the on-device model plugin.
  @override
  Future<void> prepareModel({void Function(int percent)? onProgress}) async {
    if (prepareError != null) throw prepareError!;
    if (prepare != null) {
      onProgress?.call(40);
      await prepare!.future;
    }
  }

  @override
  Future<RawMaterial> fromPdf(String path, {String? courseId}) async =>
      _mk(MaterialSource.pdf, 'pdf text', 1);

  @override
  Future<RawMaterial> fromPhoto(File image) async =>
      _mk(MaterialSource.photo, 'photo text', 0.3);

  @override
  Future<StructuredExtraction> analyze(RawMaterial m) async {
    last = m;
    if (error != null) throw error!;
    if (completer != null) return completer!.future;
    return result ??
        const StructuredExtraction(
          assignments: [],
          flashcards: _cards,
          quizItems: _quiz,
        );
  }
}

class _EmptyLlm extends llm.LlmService {
  @override
  Future<String> generate(String prompt) async =>
      '{"assignments":[],"flashcards":[],"quiz_items":[]}';
}

void main() {
  setUp(() {
    CourseStore.reset();
    StudyStore.tasks.value = const [];
  });

  Widget wrap({
    StudyIntakeService? service,
    Future<File?> Function()? photo,
    Future<String?> Function()? pdf,
  }) => MaterialApp(
    home: NotesPage(
      service: service ?? _FakeIntake(),
      capturePhoto: photo,
      pickPdf: pdf,
    ),
  );

  testWidgets('renders header, input, upload, generate and top bar', (t) async {
    await t.pumpWidget(wrap());
    expect(find.text('Notes → Flashcards & Quiz'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('✨ Generate Flashcards + Quiz'), findsOneWidget);
    expect(find.text('Save & Start Studying'), findsNothing);
    expect(find.byType(PageTopBar), findsOneWidget);
    final topBar = t.widget<PageTopBar>(find.byType(PageTopBar));
    expect(topBar.currentStep, 2);
    expect(topBar.totalSteps, 5);
  });

  testWidgets('empty input shows a SnackBar and does not call the model', (
    t,
  ) async {
    final svc = _FakeIntake();
    await t.pumpWidget(wrap(service: svc));
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pump();
    expect(find.text('Add notes, a PDF, or a photo first.'), findsOneWidget);
    expect(svc.last, isNull);
  });

  testWidgets('generate shows spinner then real preview', (t) async {
    final c = Completer<StructuredExtraction>();
    await t.pumpWidget(wrap(service: _FakeIntake(completer: c)));
    await t.enterText(find.byType(TextField), 'SN2 notes');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pump();
    expect(find.text('Generating…'), findsOneWidget);
    c.complete(
      const StructuredExtraction(
        assignments: [],
        flashcards: _cards,
        quizItems: _quiz,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Preview — edit before saving'), findsOneWidget);
    expect(find.text('FLASHCARD 1 OF 2'), findsOneWidget);
    expect(find.text('What is SN2?'), findsOneWidget);
    expect(find.text('1-question quiz ready'), findsOneWidget);
  });

  testWidgets('first-run model download shows progress, then generates', (
    t,
  ) async {
    final p = Completer<void>();
    await t.pumpWidget(wrap(service: _FakeIntake(prepare: p)));
    await t.enterText(find.byType(TextField), 'notes');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pump();
    await t.pump();
    expect(find.text('Downloading model 40%'), findsOneWidget);
    p.complete();
    await t.pumpAndSettle();
    expect(find.text('Preview — edit before saving'), findsOneWidget);
  });

  testWidgets('model download failure shows friendly SnackBar and resets', (
    t,
  ) async {
    await t.pumpWidget(
      wrap(service: _FakeIntake(prepareError: llm.HttpException('net'))),
    );
    await t.enterText(find.byType(TextField), 'notes');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't run the study model"), findsOneWidget);
    expect(find.text('✨ Generate Flashcards + Quiz'), findsOneWidget);
    expect(find.text('net'), findsNothing);
  });

  testWidgets('empty model result shows SnackBar, no preview', (t) async {
    await t.pumpWidget(
      wrap(service: _FakeIntake(result: StructuredExtraction.empty())),
    );
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Save & Start Studying'), findsNothing);
  });

  test(
    'recovers a dated exam when the model returns no structured content',
    () async {
      final service = StudyIntakeService(llm: _EmptyLlm());
      final result = await service.analyze(
        RawMaterial(
          id: 'date-only',
          source: MaterialSource.typedText,
          extractedText: 'physics exam on 15 October',
          confidence: 1,
          capturedAt: DateTime.now(),
        ),
      );

      expect(result.assignments, hasLength(1));
      expect(
        result.assignments.single.title.toLowerCase(),
        contains('physics'),
      );
      expect(result.assignments.single.type, 'exam');
      expect(result.assignments.single.dueDate?.month, 10);
      expect(result.assignments.single.dueDate?.day, 15);
      expect(result.flashcards, isEmpty);
    },
  );

  testWidgets('LLM failure shows a friendly SnackBar', (t) async {
    await t.pumpWidget(
      wrap(service: _FakeIntake(error: llm.HttpException('boom'))),
    );
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    expect(find.textContaining("Couldn't run the study model"), findsOneWidget);
    expect(find.text('boom'), findsNothing);
  });

  testWidgets('picked PDF fills the text box', (t) async {
    await t.pumpWidget(wrap(pdf: () async => '/tmp/a.pdf'));
    await t.tap(find.text('Upload PDF'));
    await t.pumpAndSettle();
    expect(find.text('pdf text'), findsOneWidget);
  });

  testWidgets('cancelled PDF pick leaves the box empty', (t) async {
    await t.pumpWidget(wrap(pdf: () async => null));
    await t.tap(find.text('Upload PDF'));
    await t.pumpAndSettle();
    expect(find.text('pdf text'), findsNothing);
  });

  testWidgets('photo fills the box and warns on low confidence', (t) async {
    await t.pumpWidget(wrap(photo: () async => File('/nonexistent.jpg')));
    await t.tap(find.text('Take photo'));
    await t.pumpAndSettle();
    expect(find.text('photo text'), findsOneWidget);
    expect(find.textContaining('Low-confidence'), findsOneWidget);
  });

  testWidgets('camera failure shows a SnackBar', (t) async {
    await t.pumpWidget(wrap(photo: () async => throw Exception('denied')));
    await t.tap(find.text('Take photo'));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Save & Start Studying opens FlashcardsPage', (t) async {
    await t.pumpWidget(wrap());
    await t.enterText(find.byType(TextField), 'notes');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Save & Start Studying'));
    await t.tap(find.text('Save & Start Studying'));
    await t.pumpAndSettle();
    expect(find.byType(FlashcardsPage), findsOneWidget);
    expect(find.byType(PageTopBar), findsOneWidget);
  });

  testWidgets('dated model results add tasks to Today', (t) async {
    final dueDate = DateTime.now().add(const Duration(days: 4));
    final service = _FakeIntake(
      result: StructuredExtraction(
        assignments: [
          ExtractedAssignment(
            title: 'Midterm review',
            type: 'exam',
            dueDate: dueDate,
          ),
        ],
        flashcards: const [],
        quizItems: const [],
      ),
    );
    await t.pumpWidget(wrap(service: service));
    await t.enterText(find.byType(TextField), 'Midterm on a future date');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    expect(find.text('Add to my plan'), findsOneWidget);
    await t.ensureVisible(find.text('Add to my plan'));
    await t.tap(find.text('Add to my plan'));
    await t.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Prep: Midterm review'), findsOneWidget);
    expect(find.textContaining('Exam due'), findsOneWidget);
  });

  testWidgets('Save & Start Studying stores the deck for the Flashcards tab', (
    t,
  ) async {
    FlashcardsPage.lastDeck = const [];
    await t.pumpWidget(wrap());
    await t.enterText(find.byType(TextField), 'notes');
    await t.tap(find.text('✨ Generate Flashcards + Quiz'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Save & Start Studying'));
    await t.tap(find.text('Save & Start Studying'));
    await t.pumpAndSettle();
    expect(FlashcardsPage.lastDeck.length, 2);
    expect(FlashcardsPage.lastCourse, 'Organic Chemistry II');
  });

  testWidgets('tapping Flashcards in the navbar opens FlashcardsPage', (
    t,
  ) async {
    await t.pumpWidget(wrap());
    await t.tap(find.text('Flashcards'));
    await t.pumpAndSettle();
    expect(find.byType(FlashcardsPage), findsOneWidget);
  });

  testWidgets('bottom nav has Today/Notes/Flashcards/Profile and no Calendar', (
    t,
  ) async {
    await t.pumpWidget(wrap());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Calendar'), findsNothing);
  });
}
