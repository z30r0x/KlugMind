/// Model backing the "Today's Plan" screen (home.dart).
/// Distinct from material_models.dart, which models the AI-ingestion
/// pipeline (RawMaterial -> StructuredExtraction), not the day's schedule.
library;

enum TaskPriority { critical, high, medium, low }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
        TaskPriority.critical => 'Critical',
        TaskPriority.high => 'High',
        TaskPriority.medium => 'Medium',
        TaskPriority.low => 'Low',
      };
}

class StudyTask {
  final String id;
  final String timeRange; // e.g. "9:00 – 9:50 AM"
  final String title;
  final String courseName;
  final TaskPriority priority;
  final bool done;
  final DateTime? date;

  const StudyTask({
    required this.id,
    required this.timeRange,
    required this.title,
    required this.courseName,
    required this.priority,
    this.done = false,
    this.date,
  });

  StudyTask copyWith({bool? done}) => StudyTask(
        id: id,
        timeRange: timeRange,
        title: title,
        courseName: courseName,
        priority: priority,
        done: done ?? this.done,
        date: date,
      );
}