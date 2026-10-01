// test/home_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/core/widgets/step_dots.dart';
import 'package:klugmind/features/profile_page/profile.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';
import 'package:klugmind/features/home_page/home.dart';

void main() {
  Widget wrap() => const MaterialApp(home: HomePage());

  setUp(CourseStore.reset);

  ElevatedButton continueButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue to Plan'),
      );

  testWidgets('renders title, subtitle, and seed courses', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Set up KlugMind'), findsOneWidget);
    expect(find.text('Organic Chemistry II'), findsOneWidget);
    expect(find.text('Linear Algebra'), findsOneWidget);
    expect(find.text('US History 1865–Present'), findsOneWidget);
    final topBar = tester.widget<PageTopBar>(find.byType(PageTopBar));
    expect(topBar.currentStep, 0);
    expect(topBar.totalSteps, 3);
    expect(find.byType(StepDots), findsOneWidget);
  });

  testWidgets('removing all courses updates list and disables Continue', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    Future<void> removeByName(String name) async {
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text(name),
            matching: find.byType(Container),
          ),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
    }

    await removeByName('Organic Chemistry II');
    expect(find.text('Organic Chemistry II'), findsNothing);
    expect(continueButton(tester).onPressed, isNotNull);

    await removeByName('Linear Algebra');
    await removeByName('US History 1865–Present');

    expect(find.text('No courses yet — add one to continue.'), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets(
    'adding a course via dialog updates list and re-enables Continue',
    (tester) async {
      await tester.pumpWidget(wrap());

      // Drain to zero first to prove Continue re-enables on add.
      for (final name in [
        'Organic Chemistry II',
        'Linear Algebra',
        'US History 1865–Present',
      ]) {
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text(name),
              matching: find.byType(Container),
            ),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(find.text('+ Add another course'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Statistics 201');
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Statistics 201'), findsOneWidget);
      expect(find.text('No courses yet — add one to continue.'), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets('cancelling add dialog does not add a course', (tester) async {
    await tester.pumpWidget(wrap());
    final countBefore = find.byIcon(Icons.close).evaluate().length;

    await tester.tap(find.text('+ Add another course'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close).evaluate().length, countBefore);
  });

  testWidgets('Continue navigates to OnboardingPage', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Continue to Plan'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text("Today's Plan"), findsOneWidget);
  });

  testWidgets('added courses sync to the Profile page', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('+ Add another course'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Statistics 201');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Statistics 201'), findsOneWidget);
  });
}
