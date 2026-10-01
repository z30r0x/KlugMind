// lib/features/profile_page/profile.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/core/widgets/theme_controller.dart';

/// Profile screen: avatar + name, three stat cards, the user's courses and
/// a settings list. The "Dark mode" switch and the top-right theme icon both
/// drive [ThemeController], so they always stay in sync.
///
/// Values are placeholders until real user data / persistence lands.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.name = 'Jordan Marsh',
    this.subtitle = 'Junior • 3 courses this semester',
    this.dayStreak = 7,
    this.cardsReviewed = 142,
    this.hoursThisWeek = '9.5h',
  });

  final String name;
  final String subtitle;
  final int dayStreak;
  final int cardsReviewed;
  final String hoursThisWeek;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _studyReminders = true;
  bool _weeklyEmail = true;
  bool _signedOut = false;

  @override
  void initState() {
    super.initState();
    CourseStore.courses.addListener(_onCoursesChanged);
  }

  @override
  void dispose() {
    CourseStore.courses.removeListener(_onCoursesChanged);
    super.dispose();
  }

  void _onCoursesChanged() {
    if (mounted) setState(() {});
  }

  String get _initials {
    final parts = widget.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final courses = CourseStore.courses.value;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      initials: _initials,
                      name: widget.name,
                      subtitle: widget.subtitle,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '${widget.dayStreak}',
                            label: 'Day streak',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: '${widget.cardsReviewed}',
                            label: 'Cards reviewed',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            value: widget.hoursThisWeek,
                            label: 'This week',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your courses',
                      style: Fonts.sectionLabel.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (courses.isEmpty)
                      Text(
                        'No courses added yet.',
                        style: Fonts.sub.copyWith(color: AppColors.textDim),
                      ),
                    for (var i = 0; i < courses.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CourseRow(
                          color: AppColors.courseColor(i),
                          course: courses[i],
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'Settings',
                      style: Fonts.sectionLabel.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Dark mode: reads and writes the app-wide ThemeController.
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.mode,
                      builder: (context, mode, _) => _SettingRow(
                        title: 'Dark mode',
                        subtitle: 'Match the app theme',
                        value: ThemeController.isDark(context),
                        onChanged: (v) => ThemeController.mode.value = v
                            ? ThemeMode.dark
                            : ThemeMode.light,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingRow(
                      title: 'Study reminders',
                      subtitle: 'Nudge before each block',
                      value: _studyReminders,
                      onChanged: (v) => setState(() => _studyReminders = v),
                    ),
                    const SizedBox(height: 10),
                    _SettingRow(
                      title: 'Weekly progress email',
                      subtitle: 'Sent every Sunday evening',
                      value: _weeklyEmail,
                      onChanged: (v) => setState(() => _weeklyEmail = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _signedOut = !_signedOut),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.priorityCriticalBg,
                          foregroundColor: AppColors.priorityCritical,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(_signedOut ? 'Sign back in' : 'Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Non-const on purpose -- see AppBottomNav's doc comment.
            AppBottomNav(active: AppTab.profile),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.initials,
    required this.name,
    required this.subtitle,
  });
  final String initials, name, subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: Fonts.h1Lg.copyWith(
                fontSize: 28,
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: Fonts.h1.copyWith(color: AppColors.textMain)),
          const SizedBox(height: 4),
          Text(subtitle, style: Fonts.sub.copyWith(color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: Fonts.h1.copyWith(color: AppColors.textMain)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Fonts.chip.copyWith(
              fontSize: 9.5,
              letterSpacing: .5,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.color, required this.course});
  final Color color;
  final AppCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              course.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          Text(
            course.hoursPerWeek,
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Fonts.caption.copyWith(color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.divider,
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
