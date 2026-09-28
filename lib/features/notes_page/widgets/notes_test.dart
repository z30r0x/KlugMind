// test/notes_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/features/notes_page/notes.dart';

void main() {
  Widget wrap() => const MaterialApp(home: NotesPage());

  testWidgets('renders header, input, upload buttons and generate button',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Notes → Flashcards & Quiz'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('✨ Generate Flashcards + Quiz'), findsOneWidget);
    expect(find.text('Save & Start Studying'), findsNothing);
  });

  testWidgets('generate shows spinner then reveals the preview',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('✨ Generate Flashcards + Quiz'));
    await tester.pump();
    expect(find.text('Generating…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Preview — edit before saving'), findsOneWidget);
    expect(find.text('FLASHCARD 1 OF 10'), findsOneWidget);
    expect(find.text('5-question quiz ready'), findsOneWidget);
    expect(find.text('Save & Start Studying'), findsOneWidget);
  });

  testWidgets('bottom nav has Today/Notes/Profile and no Calendar',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Calendar'), findsNothing);
  });
}