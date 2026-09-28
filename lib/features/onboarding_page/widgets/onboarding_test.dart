// test/onboarding_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/features/notes_page/notes.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';

void main() {
  Widget wrap() => const MaterialApp(home: OnboardingPage());

  Text titleText(WidgetTester tester, String t) =>
      tester.widget<Text>(find.text(t));

  testWidgets('renders header, editable date row, and streak badge',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text("Today's Plan"), findsOneWidget);
    expect(find.byIcon(Icons.edit_calendar_outlined), findsOneWidget);
    expect(find.text('🔥 7 day streak'), findsOneWidget);
  });

  testWidgets('renders all 5 task cards with correct priority chips',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Orgo Ch. 12 reaction mechanisms'), findsOneWidget);
    expect(find.text('Linear Algebra pset 6 review'), findsOneWidget);
    expect(find.text('Flashcards: Reconstruction Era'), findsOneWidget);
    expect(find.text('Read Ch. 14 + take notes'), findsOneWidget);
    expect(find.text('Review flashcard deck: Orgo'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsNWidgets(2));
  });

  testWidgets('completed tasks show strikethrough at start', (tester) async {
    await tester.pumpWidget(wrap());
    expect(
      titleText(tester, 'Orgo Ch. 12 reaction mechanisms').style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      titleText(tester, 'Read Ch. 14 + take notes').style?.decoration,
      TextDecoration.none,
    );
  });

  testWidgets('tapping an incomplete task completes it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Read Ch. 14 + take notes'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Read Ch. 14 + take notes').style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('tapping a completed task un-completes it (toggle both ways)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Orgo Ch. 12 reaction mechanisms'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Orgo Ch. 12 reaction mechanisms').style?.decoration,
      TextDecoration.none,
    );

    await tester.tap(find.text('Orgo Ch. 12 reaction mechanisms'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Orgo Ch. 12 reaction mechanisms').style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('tapping the date row opens the date picker', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('renders bottom nav with 3 destinations and no Calendar',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Calendar'), findsNothing);
  });

  testWidgets('tapping Notes in the navbar opens NotesPage', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
    expect(find.text('Notes → Flashcards & Quiz'), findsOneWidget);
  });

  testWidgets('renders the "I fell behind" CTA and no Focus Mode button',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('I fell behind — rebuild my week'), findsOneWidget);
    expect(find.text('Start Focus Mode'), findsNothing);
  });
}