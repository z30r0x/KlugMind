import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/services/local_storage.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores saved tasks', () async {
    final t = StudyTask(
      id: 'a', timeRange: '9', title: 'T', courseName: 'C',
      priority: TaskPriority.high, done: true, date: DateTime(2026, 10, 5),
    );
    SharedPreferences.setMockInitialValues({
      'study_tasks_v1': LocalStorage.encodeTasks([t]),
    });
    await LocalStorage.init();
    final got = StudyStore.tasks.value.single;
    expect(got.title, 'T');
    expect(got.priority, TaskPriority.high);
    expect(got.done, isTrue);
    expect(got.date, DateTime(2026, 10, 5));
  });

  test('empty storage yields empty state', () async {
    SharedPreferences.setMockInitialValues({});
    StudyStore.tasks.value = const [];
    await LocalStorage.init();
    expect(StudyStore.tasks.value, isEmpty);
  });

  test('corrupt data does not crash', () async {
    SharedPreferences.setMockInitialValues({'study_tasks_v1': '{bad'});
    await LocalStorage.init();
    expect(StudyStore.tasks.value, isEmpty);
  });

  test('deck round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    FlashcardsPage.lastDeck = const [];
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'flash_deck_v1',
      '[{"question":"Q","answer":"A","difficulty":"easy"}]',
    );
    await LocalStorage.init();
    expect(FlashcardsPage.lastDeck.single.question, 'Q');
  });
}