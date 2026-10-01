import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  LocalStorage._();
  static const _tasksKey = 'study_tasks_v1';
  static const _deckKey = 'flash_deck_v1';
  static const _courseKey = 'flash_course_v1';

  /// Call once in main() after dotenv; restores state, then autosaves.
  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    try {
      StudyStore.tasks.value = _decodeTasks(p.getString(_tasksKey));
      FlashcardsPage.lastDeck = _decodeDeck(p.getString(_deckKey));
      FlashcardsPage.lastCourse =
          p.getString(_courseKey) ?? FlashcardsPage.lastCourse;
    } catch (e) {
      debugPrint('LocalStorage restore failed: $e'); // corrupt data: start clean
    }
    StudyStore.tasks.addListener(() => saveTasks(StudyStore.tasks.value));
  }

  static Future<void> saveTasks(List<StudyTask> t) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tasksKey, encodeTasks(t));
  }

  /// Call from NotesPage._saveAndStudy after setting lastDeck.
  static Future<void> saveDeck(List<GeneratedFlashcard> d, String course) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_deckKey, encodeDeck(d));
    await p.setString(_courseKey, course);
  }

  @visibleForTesting
  static String encodeTasks(List<StudyTask> t) => jsonEncode([
    for (final x in t)
      {
        'id': x.id,
        'time': x.timeRange,
        'title': x.title,
        'course': x.courseName,
        'priority': x.priority.name,
        'done': x.done,
        'date': x.date?.toIso8601String(),
      },
  ]);

  @visibleForTesting
  static List<StudyTask> _decodeTasks(String? s) {
    if (s == null) return const [];
    return [
      for (final m in jsonDecode(s) as List)
        StudyTask(
          id: m['id'] as String,
          timeRange: m['time'] as String,
          title: m['title'] as String,
          courseName: m['course'] as String,
          priority: TaskPriority.values.byName(m['priority'] as String),
          done: m['done'] as bool? ?? false,
          date: m['date'] == null ? null : DateTime.parse(m['date'] as String),
        ),
    ];
  }

  @visibleForTesting
  static String encodeDeck(List<GeneratedFlashcard> d) => jsonEncode([
    for (final c in d)
      {'question': c.question, 'answer': c.answer, 'difficulty': c.difficulty},
  ]);

  static List<GeneratedFlashcard> _decodeDeck(String? s) => s == null
      ? const []
      : [
          for (final m in jsonDecode(s) as List)
            GeneratedFlashcard.fromJson(m as Map<String, dynamic>),
        ];
}