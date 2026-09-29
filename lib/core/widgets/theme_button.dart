// lib/core/widgets/theme_button.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'theme_controller.dart';

/// The ☾ / ☀ toggle from the prototype's status bar (`.theme-toggle`).
/// 26x26 rounded square, `bg-surface-2` fill, `divider`-colored 1px
/// border. The glyph shows the CURRENT mode: ☀ in light mode, ☾ in dark
/// mode. Tapping it switches to the other mode.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final isDark = ThemeController.isDark(context);
        return _ToggleTapTarget(
          onTap: () => ThemeController.toggle(context),
          isDark: isDark,
        );
      },
    );
  }
}

class _ToggleTapTarget extends StatelessWidget {
  const _ToggleTapTarget({required this.onTap, required this.isDark});

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // AppColors.sync must have been called by an ancestor this build pass
    // (every page's build() does `AppColors.sync(context)` first).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bgSurface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Text(
            isDark ? '☾' : '☀',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMain,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}