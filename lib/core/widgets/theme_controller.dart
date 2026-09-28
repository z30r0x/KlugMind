// lib/core/widgets/theme_controller.dart
import 'package:flutter/material.dart';

/// App-wide theme mode state, matching the prototype's `toggleTheme()` /
/// `data-theme="dark"` attribute toggle.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static bool isDark(BuildContext context) {
    switch (mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  static void toggle(BuildContext context) {
    mode.value = isDark(context) ? ThemeMode.light : ThemeMode.dark;
  }
}