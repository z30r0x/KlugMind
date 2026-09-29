// lib/core/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/notes_page/notes.dart';

/// Top-level destinations in the bottom navigation bar.
enum AppTab { today, notes, flashcards, profile }

/// Shared bottom navigation ("• Today  • Notes  • Flashcards  • Profile").
/// Each page passes only its own [active] tab; navigation is handled here.
/// Today is the root route; Notes/Flashcards replace each other instead of
/// stacking.
///
/// Callers must have run `AppColors.sync(context)` earlier in the same
/// build pass. The constructor is intentionally NOT const: a const
/// instance would be canonicalized and skip build() on rebuild, leaving
/// the bar frozen on the first-paint theme after a theme toggle.
class AppBottomNav extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  AppBottomNav({super.key, required this.active});

  final AppTab active;

  static const _labels = {
    AppTab.today: 'Today',
    AppTab.notes: 'Notes',
    AppTab.flashcards: 'Flashcards',
    AppTab.profile: 'Profile',
  };

  void _go(BuildContext context, AppTab to) {
    if (to == active) return;
    final nav = Navigator.of(context);

    if (to == AppTab.today) {
      nav.popUntil((r) => r.isFirst);
      return;
    }

    final Widget? page = switch (to) {
      AppTab.notes => const NotesPage(),
      AppTab.flashcards => FlashcardsPage(
          cards: FlashcardsPage.lastDeck,
          courseName: FlashcardsPage.lastCourse,
        ),
      AppTab.profile => null, // TODO: Profile page
      AppTab.today => null,
    };
    if (page == null) return;

    final route = MaterialPageRoute<void>(builder: (_) => page);
    if (active == AppTab.today) {
      nav.push(route);
    } else {
      nav.pushAndRemoveUntil(route, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          for (final tab in AppTab.values)
            _NavItem(
              label: _labels[tab]!,
              active: tab == active,
              onTap: () => _go(context, tab),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}