// lib/features/onboarding_page/onboarding.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/theme_button.dart';
import 'package:klugmind/core/widgets/step_dots.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/features/notes_page/notes.dart';
import 'widgets/study_task.dart';

/// "Today's Plan" home screen -- header (with editable date) + streak
/// badge, a checkable task list, and the "I fell behind" re-plan entry
/// point.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _HomePageState();
}

class _HomePageState extends State<OnboardingPage> {
  DateTime _selectedDate = DateTime.now();

  final List<StudyTask> _tasks = [
    const StudyTask(
      id: '1',
      timeRange: '9:00 – 9:50 AM',
      title: 'Orgo Ch. 12 reaction mechanisms',
      courseName: 'Organic Chemistry II',
      priority: TaskPriority.critical,
      done: true,
    ),
    const StudyTask(
      id: '2',
      timeRange: '10:15 – 11:00 AM',
      title: 'Linear Algebra pset 6 review',
      courseName: 'Linear Algebra',
      priority: TaskPriority.high,
      done: true,
    ),
    const StudyTask(
      id: '3',
      timeRange: '1:00 – 1:45 PM',
      title: 'Flashcards: Reconstruction Era',
      courseName: 'US History',
      priority: TaskPriority.medium,
      done: true,
    ),
    const StudyTask(
      id: '4',
      timeRange: '3:30 – 4:15 PM',
      title: 'Read Ch. 14 + take notes',
      courseName: 'US History',
      priority: TaskPriority.low,
    ),
    const StudyTask(
      id: '5',
      timeRange: '6:00 – 6:30 PM',
      title: 'Review flashcard deck: Orgo',
      courseName: 'Organic Chemistry II',
      priority: TaskPriority.low,
    ),
  ];

  void _toggle(String id) {
    setState(() {
      final i = _tasks.indexWhere((t) => t.id == id);
      if (i == -1) return;
      _tasks[i] = _tasks[i].copyWith(done: !_tasks[i].done);
    });
  }

  void _onNavSelect(AppTab tab) {
    switch (tab) {
      case AppTab.today:
        return;
      case AppTab.notes:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotesPage()),
        );
      case AppTab.profile:
        // TODO: navigate to Profile once that page exists.
        return;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Syncs AppColors' static getters to the current brightness for this
    // entire build pass -- every widget below reads AppColors.xxx directly.
    AppColors.sync(context);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [SizedBox.shrink(), ThemeButton()],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Step 2 of 2: HomePage (course setup) -> here.
                        const StepDots(currentStep: 1, totalSteps: 2),
                        const SizedBox(height: 16),
                        _Header(date: _selectedDate, onDateTap: _pickDate),
                        const SizedBox(height: 18),
                        Text('Study blocks',
                            style: Fonts.sectionLabel
                                .copyWith(color: AppColors.textDim)),
                        const SizedBox(height: 10),
                        for (final task in _tasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskCard(
                              task: task,
                              onTap: () => _toggle(task.id),
                            ),
                          ),
                        const SizedBox(height: 6),
                        const _BehindButton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // Non-const on purpose -- see AppBottomNav's doc comment.
            AppBottomNav(active: AppTab.today, onSelect: _onNavSelect),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Plan",
                style: Fonts.h1.copyWith(color: AppColors.textMain)),
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
                      Text(_formatted,
                          style:
                              Fonts.sub.copyWith(color: AppColors.textDim)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_calendar_outlined,
                          size: 14, color: AppColors.textDim),
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
                    Text(task.timeRange,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textFaint,
                        )),
                    _PriorityChip(
                        label: task.priority.label,
                        fg: _fg(task.priority),
                        bg: _bg(task.priority)),
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
                          Text(task.courseName,
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.textDim)),
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
  const _PriorityChip(
      {required this.label, required this.fg, required this.bg});

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
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
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

// ---------------------------------------------------------------------------
// "I fell behind" CTA
// ---------------------------------------------------------------------------

class _BehindButton extends StatelessWidget {
  const _BehindButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // TODO: wire to re-planning route (screen-replan).
          // Navigator.of(context).pushNamed('/replan');
        },
        icon: const Icon(Icons.warning_amber_rounded, size: 16),
        label: const Text('I fell behind — rebuild my week',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.priorityHighBg,
          foregroundColor: AppColors.priorityHigh,
          padding: const EdgeInsets.symmetric(vertical: 13),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}