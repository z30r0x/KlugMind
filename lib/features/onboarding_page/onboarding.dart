// lib/features/onboarding_page/onboarding.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/core/services/voice_service.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/features/flashcards_page/flashcard_view.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'widgets/study_task.dart';

/// "Today's Plan" home screen with date-specific example and imported tasks.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<OnboardingPage> createState() => _HomePageState();
}

class _HomePageState extends State<OnboardingPage> {
  late DateTime _selectedDate;
  final Map<String, bool> _exampleCompletion = {};
  final _voiceService = VoiceService();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    StudyStore.tasks.addListener(_onPlan);
  }

  @override
  void dispose() {
    StudyStore.tasks.removeListener(_onPlan);
    unawaited(_voiceService.cancel());
    super.dispose();
  }

  void _onPlan() {
    if (mounted) setState(() {});
  }

  void _toggle(String id) {
    if (StudyStore.toggle(id)) return;
    final current = _tasksForDate(
      _selectedDate,
    ).firstWhere((task) => task.id == id).done;
    setState(() {
      _exampleCompletion[id] = !current;
    });
  }

  List<StudyTask> _tasksForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final dayIndex = day.difference(DateTime(day.year)).inDays % 3;
    final courses = CourseStore.courses.value;
    final examples = switch (dayIndex) {
      0 => const [
        (
          'Orgo Ch. 12 reaction mechanisms',
          '9:00 – 9:50 AM',
          TaskPriority.critical,
          true,
        ),
        (
          'Linear Algebra pset 6 review',
          '10:15 – 11:00 AM',
          TaskPriority.high,
          true,
        ),
        (
          'Flashcards: Reconstruction Era',
          '1:00 – 1:45 PM',
          TaskPriority.medium,
          true,
        ),
        ('Read Ch. 14 + take notes', '3:30 – 4:15 PM', TaskPriority.low, false),
        (
          'Review flashcard deck: Orgo',
          '6:00 – 6:30 PM',
          TaskPriority.low,
          false,
        ),
      ],
      1 => const [
        ('Preview the next lecture', '9:00 – 9:30 AM', TaskPriority.low, false),
        (
          'Complete practice questions',
          '10:00 – 10:50 AM',
          TaskPriority.high,
          false,
        ),
        ('Review key terms', '1:00 – 1:30 PM', TaskPriority.medium, false),
        ('Summarize the lecture', '3:00 – 3:45 PM', TaskPriority.medium, false),
        (
          'Preview tomorrow\'s assignment',
          '6:00 – 6:30 PM',
          TaskPriority.low,
          false,
        ),
      ],
      _ => const [
        (
          'Summarize this week\'s notes',
          '9:00 – 9:45 AM',
          TaskPriority.medium,
          false,
        ),
        (
          'Work through the problem set',
          '10:30 – 11:20 AM',
          TaskPriority.high,
          false,
        ),
        (
          'Prepare for the next quiz',
          '1:00 – 1:45 PM',
          TaskPriority.critical,
          false,
        ),
        (
          'Review marked questions',
          '3:30 – 4:00 PM',
          TaskPriority.medium,
          false,
        ),
        ('Make a short recap sheet', '6:00 – 6:30 PM', TaskPriority.low, false),
      ],
    };
    final sampleTasks = [
      for (var i = 0; i < examples.length; i++)
        StudyTask(
          id: 'sample-${day.year}-${day.month}-${day.day}-$i',
          timeRange: examples[i].$2,
          title: examples[i].$1,
          courseName: courses.isEmpty
              ? 'Independent study'
              : courses[(dayIndex + i) % courses.length].name,
          priority: examples[i].$3,
          done:
              _exampleCompletion['sample-${day.year}-${day.month}-${day.day}-$i'] ??
              examples[i].$4,
          date: day,
        ),
    ];
    final importedTasks = StudyStore.tasks.value.where(
      (task) => task.date != null && DateUtils.isSameDay(task.date, day),
    );
    return [...importedTasks, ...sampleTasks];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addStudyBlock() async {
    final courses = CourseStore.courses.value;
    var courseName = courses.isEmpty ? 'Independent study' : courses.first.name;
    var title = '';
    var time = '';
    var priority = TaskPriority.medium;
    final task = await showModalBottomSheet<StudyTask>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add a study task',
                  style: Fonts.h1.copyWith(color: AppColors.textMain),
                ),
                const SizedBox(height: 10),
                Text(
                  'Task',
                  style: Fonts.caption.copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                TextField(
                  autofocus: true,
                  maxLength: 60,
                  onChanged: (value) => title = value,
                  decoration: InputDecoration(
                    hintText: 'e.g. Review Chapter 5',
                    filled: true,
                    fillColor: AppColors.bgSurface2,
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'Dictate task',
                      icon: const Icon(Icons.mic_none),
                      onPressed: () async {
                        try {
                          await _voiceService.listenAndTranscribe(
                            onPartialResult: (partial) {
                              title = partial;
                              setSheetState(() {});
                            },
                          );
                        } catch (error) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Course',
                  style: Fonts.caption.copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                if (courses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: courseName,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.bgSurface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (final course in courses)
                        DropdownMenuItem(
                          value: course.name,
                          child: Text(course.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => courseName = value);
                      }
                    },
                  ),
                const SizedBox(height: 10),
                Text(
                  'Time (optional)',
                  style: Fonts.caption.copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (value) => time = value,
                  decoration: InputDecoration(
                    hintText: 'e.g. 7:00 – 7:45 PM',
                    filled: true,
                    fillColor: AppColors.bgSurface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Priority',
                  style: Fonts.caption.copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in TaskPriority.values)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: priority == option,
                        onSelected: (_) =>
                            setSheetState(() => priority = option),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (title.trim().isEmpty) return;
                          Navigator.of(sheetContext).pop(
                            StudyTask(
                              id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
                              timeRange: time.trim().isEmpty
                                  ? 'Anytime today'
                                  : time.trim(),
                              title: title.trim(),
                              courseName: courseName,
                              priority: priority,
                              date: DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              ),
                            ),
                          );
                        },
                        child: const Text('Add task'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (task != null) {
      StudyStore.add([task]);
      setState(() => _selectedDate = task!.date ?? _selectedDate);
    }
  }

  void _startFocusMode() {
    final deck = FlashcardsPage.lastDeck;
    if (deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create flashcards to start focus mode.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardSession(
          cards: deck,
          courseName: FlashcardsPage.lastCourse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Syncs AppColors' static getters to the current brightness for this
    // entire build pass -- every widget below reads AppColors.xxx directly.
    AppColors.sync(context);
    final tasks = _tasksForDate(_selectedDate);
    final completedCount = tasks.where((task) => task.done).length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: FloatingActionButton(
          onPressed: _addStudyBlock,
          tooltip: 'Add task',
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 30),
        ),
      ),
      // Keep the navbar pinned to the bottom if a text field is added later.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: PageTopBar()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _Header(date: _selectedDate, onDateTap: _pickDate),
                        const SizedBox(height: 18),
                        _ProgressCard(
                          completed: completedCount,
                          total: tasks.length,
                          onStartFocus: _startFocusMode,
                        ),
                        Text(
                          'Study blocks',
                          style: Fonts.sectionLabel.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final task in tasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskCard(
                              task: task,
                              onTap: () => _toggle(task.id),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // Non-const on purpose -- see AppBottomNav's doc comment.
            AppBottomNav(active: AppTab.today),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.onStartFocus,
  });

  final int completed;
  final int total;
  final VoidCallback onStartFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$completed of $total study blocks done',
            style: Fonts.bodyBold.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 8,
              color: AppColors.onPrimary,
              backgroundColor: AppColors.onPrimary.withAlpha(64),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartFocus,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start Focus Mode'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.onPrimary,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date, required this.onDateTap});

  final DateTime date;
  final VoidCallback onDateTap;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  String get _formatted =>
      '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Plan",
                style: Fonts.h1.copyWith(color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              Semantics(
                button: true,
                label: 'Change date, currently $_formatted',
                child: InkWell(
                  onTap: onDateTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatted,
                          style: Fonts.sub.copyWith(color: AppColors.textDim),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 14,
                          color: AppColors.textDim,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '🔥 7 day streak',
              style: Fonts.chip.copyWith(
                fontSize: 11.5,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable task card (exported so calendar/other pages can reuse it)
// ---------------------------------------------------------------------------

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final StudyTask task;
  final VoidCallback onTap;

  static Color _fg(TaskPriority p) => switch (p) {
    TaskPriority.critical => AppColors.priorityCritical,
    TaskPriority.high => AppColors.priorityHigh,
    TaskPriority.medium => AppColors.priorityMedium,
    TaskPriority.low => AppColors.priorityLow,
  };

  static Color _bg(TaskPriority p) => switch (p) {
    TaskPriority.critical => AppColors.priorityCriticalBg,
    TaskPriority.high => AppColors.priorityHighBg,
    TaskPriority.medium => AppColors.priorityMediumBg,
    TaskPriority.low => AppColors.priorityLowBg,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${task.title}, ${task.courseName}, ${task.priority.label} priority'
          '${task.done ? ', completed' : ''}',
      child: Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      task.timeRange,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textFaint,
                      ),
                    ),
                    _PriorityChip(
                      label: task.priority.label,
                      fg: _fg(task.priority),
                      bg: _bg(task.priority),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DoneCheckbox(done: task.done),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: task.done
                                  ? AppColors.textFaint
                                  : AppColors.textMain,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.courseName,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _DoneCheckbox extends StatelessWidget {
  const _DoneCheckbox({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.success : AppColors.bgSurface,
        border: Border.all(
          color: done ? AppColors.success : AppColors.divider,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: done
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}
