import 'package:flutter/foundation.dart';

class AppCourse {
  const AppCourse({
    required this.id,
    required this.name,
    this.hoursPerWeek = '—/wk',
  });

  final String id;
  final String name;
  final String hoursPerWeek;
}

class CourseStore {
  CourseStore._();

  static final ValueNotifier<List<AppCourse>> courses =
      ValueNotifier<List<AppCourse>>(_starterCourses());
  static int _nextId = 4;

  static List<AppCourse> _starterCourses() => const [
    AppCourse(id: '1', name: 'Organic Chemistry II', hoursPerWeek: '6h/wk'),
    AppCourse(id: '2', name: 'Linear Algebra', hoursPerWeek: '4h/wk'),
    AppCourse(id: '3', name: 'US History 1865–Present', hoursPerWeek: '3h/wk'),
  ];

  static bool add(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty ||
        courses.value.any(
          (course) => course.name.toLowerCase() == normalized.toLowerCase(),
        )) {
      return false;
    }
    courses.value = [
      ...courses.value,
      AppCourse(id: 'course-${_nextId++}', name: normalized),
    ];
    return true;
  }

  static bool remove(String id) {
    final next = courses.value.where((course) => course.id != id).toList();
    if (next.length == courses.value.length) return false;
    courses.value = next;
    return true;
  }

  static void reset() {
    _nextId = 4;
    courses.value = _starterCourses();
  }
}
