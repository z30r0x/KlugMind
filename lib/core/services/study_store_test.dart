import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';

void main() {
  final now = DateTime(2026, 10, 1);

  setUp(() => StudyStore.tasks.value = const []);

  test(
    'undated assignments are skipped and overdue assignments surface today',
    () {
      final out = StudyStore.blocksFrom([
        const ExtractedAssignment(title: 'a', type: 'exam'),
        ExtractedAssignment(
          title: 'b',
          type: 'exam',
          dueDate: DateTime(2026, 9, 1),
        ),
      ], now: now);
      expect(out, hasLength(1));
      expect(out.single.date, now);
      expect(out.single.title, contains('Overdue: Prep: b'));
    },
  );

  test('exam 10 days out: study day before, 90 min, medium priority', () {
    final out = StudyStore.blocksFrom([
      ExtractedAssignment(
        title: 'Final',
        type: 'exam',
        dueDate: DateTime(2026, 10, 11),
      ),
    ], now: now);
    expect(out.single.date, DateTime(2026, 10, 10));
    expect(out.single.timeRange, contains('90 min'));
    expect(out.single.priority, TaskPriority.medium);
  });

  test('due today is critical; heavy weight bumps urgency', () {
    final today = StudyStore.blocksFrom([
      ExtractedAssignment(title: 'x', type: 'quiz', dueDate: now),
    ], now: now);
    expect(today.single.priority, TaskPriority.critical);
    final heavy = StudyStore.blocksFrom([
      ExtractedAssignment(
        title: 'y',
        type: 'project',
        weight: 0.3,
        dueDate: DateTime(2026, 10, 5),
      ),
    ], now: now);
    expect(heavy.single.priority, TaskPriority.critical);
  });

  test('empty type does not crash', () {
    final out = StudyStore.blocksFrom([
      ExtractedAssignment(title: 'z', type: '', dueDate: DateTime(2026, 10, 3)),
    ], now: now);
    expect(out.length, 1);
  });

  test('add sorts by date and toggle flips done', () {
    final a = StudyStore.blocksFrom([
      ExtractedAssignment(
        title: 'late',
        type: 'exam',
        dueDate: DateTime(2026, 10, 20),
      ),
      ExtractedAssignment(
        title: 'soon',
        type: 'exam',
        dueDate: DateTime(2026, 10, 3),
      ),
    ], now: now);
    StudyStore.add(a);
    expect(StudyStore.tasks.value.first.title, contains('soon'));
    final id = StudyStore.tasks.value.first.id;
    expect(StudyStore.toggle(id), isTrue);
    expect(StudyStore.tasks.value.first.done, isTrue);
    expect(StudyStore.toggle('missing'), isFalse);
  });
}
