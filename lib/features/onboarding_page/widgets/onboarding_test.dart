// test/onboarding_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/notes_page/notes.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';

final _today = DateTime.now();
final _plan = [
  StudyTask(
    id: 'exam-1',
    timeRange: 'Oct 10 · 90 min',
    title: 'Prep: Midterm',
    courseName: 'Exam due Oct 11',
    priority: TaskPriority.critical,
    done: true,
    date: DateTime(_today.year, _today.month, _today.day),
  ),
  StudyTask(
    id: 'assignment-1',
    timeRange: 'Oct 11 · 60 min',
    title: 'Work on: Essay',
    courseName: 'Assignment due Oct 12',
    priority: TaskPriority.high,
    date: DateTime(_today.year, _today.month, _today.day),
  ),
];

void main() {
  Widget wrap() => const MaterialApp(home: OnboardingPage());

  setUp(() {
    CourseStore.reset();
    StudyStore.tasks.value = _plan;
  });

  Text titleText(WidgetTester tester, String t) =>
      tester.widget<Text>(find.text(t));

  testWidgets('renders plan header, date, streak and progress card', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    expect(find.text("Today's Plan"), findsOneWidget);
    expect(find.byIcon(Icons.edit_calendar_outlined), findsOneWidget);
    expect(find.text('🔥 7 day streak'), findsOneWidget);
    expect(find.text('4 of 7 study blocks done'), findsOneWidget);
    expect(find.text('Start Focus Mode'), findsOneWidget);
  });

  testWidgets('renders imported exam and assignment cards', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Prep: Midterm'), findsOneWidget);
    expect(find.text('Exam due Oct 11'), findsOneWidget);
    expect(find.text('Work on: Essay'), findsOneWidget);
    expect(find.text('Assignment due Oct 12'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('High'), findsWidgets);
  });

  testWidgets('example tasks change with the selected date', (tester) async {
    await tester.pumpWidget(wrap());
    final before = tester
        .widgetList<TaskCard>(find.byType(TaskCard))
        .map((card) => card.task.title)
        .toSet();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${tomorrow.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<TaskCard>(find.byType(TaskCard))
        .map((card) => card.task.title)
        .toSet();
    expect(after.intersection(before), isEmpty);
  });

  testWidgets('completed tasks show strikethrough at start', (tester) async {
    await tester.pumpWidget(wrap());
    expect(
      titleText(tester, 'Prep: Midterm').style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      titleText(tester, 'Work on: Essay').style?.decoration,
      TextDecoration.none,
    );
  });

  testWidgets('tapping an incomplete task completes it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Work on: Essay'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Work on: Essay').style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('tapping a completed task un-completes it (toggle both ways)', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Prep: Midterm'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Prep: Midterm').style?.decoration,
      TextDecoration.none,
    );

    await tester.tap(find.text('Prep: Midterm'));
    await tester.pumpAndSettle();
    expect(
      titleText(tester, 'Prep: Midterm').style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('tapping the date row opens the date picker', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('renders bottom nav with 4 destinations and no Calendar', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
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

  testWidgets('tapping Flashcards in the navbar opens FlashcardsPage', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    expect(find.byType(FlashcardsPage), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);
  });

  testWidgets('shows focus mode but not the removed re-plan action', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    expect(find.text('I fell behind — rebuild my week'), findsNothing);
    expect(find.text('Start Focus Mode'), findsOneWidget);
  });

  testWidgets('adds a dated study block from the Today page', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Review calculus notes',
    );
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    expect(
      StudyStore.tasks.value.any(
        (task) => task.title == 'Review calculus notes',
      ),
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Review calculus notes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Review calculus notes'), findsOneWidget);
    expect(
      StudyStore.tasks.value.any(
        (task) =>
            task.title == 'Review calculus notes' &&
            task.courseName == 'Organic Chemistry II',
      ),
      isTrue,
    );
    expect(StudyStore.tasks.value, hasLength(3));
  });
}
