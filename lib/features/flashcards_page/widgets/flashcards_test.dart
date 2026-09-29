import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';

const _cards = [
  GeneratedFlashcard(question: 'Q1?', answer: 'A1', difficulty: 'easy'),
  GeneratedFlashcard(question: 'Q2?', answer: 'A2', difficulty: 'hard'),
];

Widget wrap({
  List<GeneratedFlashcard> cards = _cards,
  ValueChanged<List<CardRating>>? onFinished,
}) =>
    MaterialApp(
      home: FlashcardsPage(
        cards: cards,
        courseName: 'Organic Chemistry II',
        onFinished: onFinished,
      ),
    );

VoidCallback? _tapOf(WidgetTester t, String label) => t
    .widget<InkWell>(find
        .ancestor(of: find.text(label), matching: find.byType(InkWell))
        .first)
    .onTap;

void main() {
  testWidgets('renders first card, counter, streak and hint', (t) async {
    await t.pumpWidget(wrap());
    expect(find.text('Card 1 of 2'), findsOneWidget);
    expect(find.text('ORGANIC CHEMISTRY II'), findsOneWidget);
    expect(find.text('Q1?'), findsOneWidget);
    expect(find.text('Tap to reveal answer'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('rating buttons are disabled until the answer is revealed',
      (t) async {
    await t.pumpWidget(wrap());
    expect(_tapOf(t, 'Good'), isNull);
    await t.tap(find.text('Q1?'));
    await t.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(_tapOf(t, 'Good'), isNotNull);
  });

  testWidgets('rating advances and finishing reports ratings', (t) async {
    List<CardRating>? got;
    await t.pumpWidget(wrap(onFinished: (r) => got = r));
    await t.tap(find.text('Q1?'));
    await t.pumpAndSettle();
    await t.tap(find.text('Again'));
    await t.pumpAndSettle();
    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(find.text('Q2?'), findsOneWidget);
    await t.tap(find.text('Q2?'));
    await t.pumpAndSettle();
    await t.tap(find.text('Easy'));
    await t.pumpAndSettle();
    expect(got, [CardRating.again, CardRating.easy]);
    expect(find.text('Session complete'), findsOneWidget);
  });

  testWidgets('empty deck shows empty state', (t) async {
    await t.pumpWidget(wrap(cards: const []));
    expect(find.text('No cards to study'), findsOneWidget);
  });

  testWidgets('shows the bottom nav with the Flashcards tab', (t) async {
    await t.pumpWidget(wrap());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}