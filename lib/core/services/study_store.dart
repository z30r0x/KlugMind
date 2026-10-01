import 'package:flutter/foundation.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';

/// In-memory plan store: turns dated assignments into study blocks.
/// Swap for Hive/Supabase later.
class StudyStore {
  StudyStore._();

  static final ValueNotifier<List<StudyTask>> tasks =
      ValueNotifier<List<StudyTask>>(const []);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// One study block per dated assignment; overdue items are surfaced today.
  static List<StudyTask> blocksFrom(
    List<ExtractedAssignment> items, {
    DateTime? now,
    String? courseName,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final out = <StudyTask>[];
    var i = 0;
    for (final a in items) {
      final d = a.dueDate;
      if (d == null) continue;
      final due = DateTime(d.year, d.month, d.day);
      final days = due.difference(today).inDays;
      final overdue = days < 0;
      final studyDay = overdue
          ? today
          : days > 1
          ? due.subtract(const Duration(days: 1))
          : due;
      final type = a.type.isEmpty ? 'assignment' : a.type;
      final mins = switch (type) {
        'exam' || 'project' => 90,
        'quiz' => 45,
        _ => 60,
      };
      final prep = type == 'exam' || type == 'quiz';
      out.add(
        StudyTask(
          id: '$stamp-${i++}',
          timeRange:
              '${_months[studyDay.month - 1]} ${studyDay.day} · $mins min',
          title: overdue
              ? 'Overdue: ${prep ? 'Prep' : 'Work on'}: ${a.title}'
              : '${prep ? 'Prep' : 'Work on'}: ${a.title}',
          courseName: courseName == null || courseName.trim().isEmpty
              ? '${type[0].toUpperCase()}${type.substring(1)} due ${_months[due.month - 1]} ${due.day}'
              : '$courseName · ${type[0].toUpperCase()}${type.substring(1)} due ${_months[due.month - 1]} ${due.day}',
          priority: _priority(overdue ? 0 : days, a.weight),
          date: studyDay,
        ),
      );
    }
    out.sort((x, y) => x.date!.compareTo(y.date!));
    return out;
  }

  static TaskPriority _priority(int daysLeft, double? weight) {
    var p = daysLeft <= 2
        ? 0
        : daysLeft <= 5
        ? 1
        : daysLeft <= 10
        ? 2
        : 3;
    if ((weight ?? 0) >= 0.2 && p > 0) p--; // heavy weight bumps urgency
    return TaskPriority.values[p];
  }

  static void add(List<StudyTask> blocks) {
    final all = [...tasks.value, ...blocks]
      ..sort(
        (a, b) =>
            (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)),
      );
    tasks.value = all;
  }

  /// Returns true if [id] belonged to the store.
  static bool toggle(String id) {
    final i = tasks.value.indexWhere((t) => t.id == id);
    if (i == -1) return false;
    final next = [...tasks.value];
    next[i] = next[i].copyWith(done: !next[i].done);
    tasks.value = next;
    return true;
  }
}
