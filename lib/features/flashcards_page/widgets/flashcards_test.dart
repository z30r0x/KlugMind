import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/core/widgets/theme_button.dart';
import 'package:klugmind/core/widgets/theme_controller.dart';
import 'package:klugmind/features/flashcards_page/flashcard_view.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';

const _cards = [
  GeneratedFlashcard(question: 'Q1?', answer: 'A1', difficulty: 'easy'),
  GeneratedFlashcard(question: 'Q2?', answer: 'A2', difficulty: 'hard'),
];

Widget wrap({
  List<GeneratedFlashcard> cards = _cards,
  ValueChanged<List<CardRating>>? onFinished,
}) => MaterialApp(
  home: FlashcardSession(
    cards: cards,
    courseName: 'Organic Chemistry II',
    onFinished: onFinished,
  ),
);

VoidCallback? _tapOf(WidgetTester t, String label) => t
    .widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    )
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
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('deck overview lists created cards and starts learning', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: FlashcardsPage(cards: _cards, courseName: 'Organic Chemistry II'),
      ),
    );
    expect(find.text('Flashcards'), findsNWidgets(2));
    expect(find.text('Q1?'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Q2?'), findsOneWidget);
    final topBar = t.widget<PageTopBar>(find.byType(PageTopBar));
    expect(topBar.currentStep, 3);
    expect(topBar.totalSteps, 5);
    await t.tap(find.text('Start learning').first);
    await t.pumpAndSettle();
    expect(find.byType(FlashcardSession), findsOneWidget);
    expect(find.text('Card 1 of 2'), findsOneWidget);
  });

  testWidgets('rating buttons are disabled until the answer is revealed', (
    t,
  ) async {
    await t.pumpWidget(wrap());
    expect(_tapOf(t, 'Good'), isNull);
    await t.tap(find.text('Q1?'));
    await t.pumpAndSettle();
    expect(find.text('A1'), findsOneWidget);
    expect(_tapOf(t, 'Good'), isNotNull);
  });

  testWidgets('swiping cards updates the counter and progress bar', (t) async {
    await t.pumpWidget(wrap());
    await t.drag(find.byType(PageView), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(find.text('Card 2 of 2'), findsOneWidget);
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
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
    expect(find.text('Card 3 of 2'), findsOneWidget);
    expect(find.text('Back to plan'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('empty deck shows empty state', (t) async {
    await t.pumpWidget(wrap(cards: const []));
    expect(find.text('No cards to study'), findsOneWidget);
  });

  testWidgets('bottom navigation keeps its four fixed circular markers', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: AppBottomNav(active: AppTab.flashcards),
        ),
      ),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    List<Container> markers(Finder nav) => t
        .widgetList<Container>(
          find.descendant(of: nav, matching: find.byType(Container)),
        )
        .where(
          (marker) =>
              marker.constraints ==
              const BoxConstraints.tightFor(width: 6, height: 6),
        )
        .toList();

    final initialMarkers = markers(find.byType(AppBottomNav).first);
    expect(initialMarkers, hasLength(4));
    expect(
      initialMarkers.every(
        (marker) =>
            (marker.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
      isTrue,
    );
    await t.tap(find.text('Notes'));
    await t.pumpAndSettle();
    expect(markers(find.byType(AppBottomNav).last), hasLength(4));
  });

  testWidgets('empty state shows theme toggle and back action', (t) async {
    await t.pumpWidget(wrap(cards: const []));
    expect(find.byType(ThemeButton), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
  });

  testWidgets('theme icon shows a sun in light mode and a moon in dark mode', (
    t,
  ) async {
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
