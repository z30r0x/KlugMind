// lib/core/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';

/// Top-level destinations in the bottom navigation bar.
enum AppTab { today, notes, profile }

/// Shared bottom navigation ("• Today  • Notes  • Profile") used by every
/// top-level screen. Each page passes its own [active] tab and decides
/// what to do in [onSelect].
///
/// Callers must have run `AppColors.sync(context)` earlier in the same
/// build pass. The constructor is intentionally NOT const: a const
/// instance would be canonicalized and skip build() on rebuild, leaving
/// the bar frozen on the first-paint theme after a theme toggle.
class AppBottomNav extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  AppBottomNav({super.key, required this.active, required this.onSelect});

  final AppTab active;
  final ValueChanged<AppTab> onSelect;

  static const _labels = {
    AppTab.today: 'Today',
    AppTab.notes: 'Notes',
    AppTab.profile: 'Profile',
  };

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
              onTap: () => onSelect(tab),
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