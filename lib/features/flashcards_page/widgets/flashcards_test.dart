import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/core/widgets/step_dots.dart';
import 'package:klugmind/core/widgets/theme_button.dart';
import 'package:klugmind/core/widgets/theme_controller.dart';
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
  tearDown(() => ThemeController.mode.value = ThemeMode.system);

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

  testWidgets('study view shows step dots and theme toggle', (t) async {
    await t.pumpWidget(wrap());
    expect(find.byType(PageTopBar), findsOneWidget);
    expect(find.byType(StepDots), findsOneWidget);
    expect(find.byType(ThemeButton), findsOneWidget);
  });

  testWidgets('empty state shows step dots, theme toggle and centered message',
      (t) async {
    await t.pumpWidget(wrap(cards: const []));
    expect(find.byType(StepDots), findsOneWidget);
    expect(find.byType(ThemeButton), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    // The message block is centered horizontally on screen.
    final center = t.getCenter(find.text('No cards to study'));
    expect(center.dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, 1));
  });

  testWidgets('theme icon shows a sun in light mode and a moon in dark mode',
      (t) async {
    ThemeController.mode.value = ThemeMode.light;
    await t.pumpWidget(wrap());
    expect(find.text('☀'), findsOneWidget);
    expect(find.text('☾'), findsNothing);

    ThemeController.mode.value = ThemeMode.dark;
    await t.pump();
    expect(find.text('☾'), findsOneWidget);
    expect(find.text('☀'), findsNothing);
  });

  testWidgets('tapping the theme icon switches the glyph', (t) async {
    ThemeController.mode.value = ThemeMode.light;
    await t.pumpWidget(wrap());
    await t.tap(find.text('☀'));
    await t.pump();
    expect(find.text('☾'), findsOneWidget);
  });
}