import 'package:flutter/material.dart';

/// Raw hex string palette -- single source of truth for every color.
class ColorHex {
  ColorHex._();

  // Light theme
  static const String bgApp = '#F6F7FB';
  static const String bgSurface = '#FFFFFF';
  static const String bgSurface2 = '#EEF0F5';
  static const String primary = '#3B5BFD';
  static const String primarySoft = '#E4E9FF';
  static const String onPrimary = '#FFFFFF';
  static const String onPrimaryContainer = '#1A2C8F';
  static const String textMain = '#16181D';
  static const String textDim = '#5A6070';
  static const String textFaint = '#9AA1B2';
  static const String divider = '#E3E6ED';
  static const String priorityCritical = '#D92D20';
  static const String priorityCriticalBg = '#FEE4E2';
  static const String priorityHigh = '#F79009';
  static const String priorityHighBg = '#FEF0C7';
  static const String priorityMedium = '#175CD3';
  static const String priorityMediumBg = '#D1E0FF';
  static const String priorityLow = '#12805C';
  static const String priorityLowBg = '#D3F8E6';
  static const String success = '#12B76A';
  static const String statusColor = '#6172F3';

  // Dark theme
  static const String bgAppDark = '#0E0F13';
  static const String bgSurfaceDark = '#17181D';
  static const String bgSurface2Dark = '#20222A';
  static const String primaryDark = '#8B9DFF';
  static const String primarySoftDark = '#262E55';
  static const String onPrimaryDark = '#10143A';
  static const String onPrimaryContainerDark = '#DDE3FF';
  static const String textMainDark = '#ECEDF1';
  static const String textDimDark = '#A6ACBA';
  static const String textFaintDark = '#666D7E';
  static const String dividerDark = '#2A2D36';
  static const String priorityCriticalDark = '#F97066';
  static const String priorityCriticalBgDark = '#3A1C1A';
  static const String priorityHighDark = '#FDB022';
  static const String priorityHighBgDark = '#3B2A12';
  static const String priorityMediumDark = '#84ADFF';
  static const String priorityMediumBgDark = '#1A2A4D';
  static const String priorityLowDark = '#32D583';
  static const String priorityLowBgDark = '#123527';
  static const String successDark = '#32D583';
  static const String statusColorDark = '#A5B4FC';

  /// Course color-dot palette (theme-invariant), raw hex strings.
  static const List<String> coursePalette = [
    '#3B5BFD', '#F79009', '#12B76A', '#D92D20',
    '#8B5CF6', '#EC4899', '#06B6D4', '#84ADFF',
  ];

  /// Parse any hex string ('#RRGGBB' or 'RRGGBB') to a Color.
  static Color parse(String value) {
    final hex = value.startsWith('#') ? value.substring(1) : value;
    return Color(int.parse('FF$hex', radix: 16));
  }
}

/// Typed color tokens, used as `AppColors.textMain` on any page.
/// Call `AppColors.sync(context)` once at the top of each screen's build().
class AppColors {
  AppColors._();

  static _Palette _active = _light;

  static void sync(BuildContext context) {
    _active =
        Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }

  static Color get bgApp => _active.bgApp;
  static Color get bgSurface => _active.bgSurface;
  static Color get bgSurface2 => _active.bgSurface2;
  static Color get primary => _active.primary;
  static Color get primarySoft => _active.primarySoft;
  static Color get onPrimary => _active.onPrimary;
  static Color get onPrimaryContainer => _active.onPrimaryContainer;
  static Color get textMain => _active.textMain;
  static Color get textDim => _active.textDim;
  static Color get textFaint => _active.textFaint;
  static Color get divider => _active.divider;
  static Color get priorityCritical => _active.priorityCritical;
  static Color get priorityCriticalBg => _active.priorityCriticalBg;
  static Color get priorityHigh => _active.priorityHigh;
  static Color get priorityHighBg => _active.priorityHighBg;
  static Color get priorityMedium => _active.priorityMedium;
  static Color get priorityMediumBg => _active.priorityMediumBg;
  static Color get priorityLow => _active.priorityLow;
  static Color get priorityLowBg => _active.priorityLowBg;
  static Color get success => _active.success;
  static Color get statusColor => _active.statusColor;

  /// Resolves a course palette color by index (wraps around, never throws).
  static Color courseColor(int index) =>
      ColorHex.parse(ColorHex.coursePalette[index % ColorHex.coursePalette.length]);

  static List<Color> get coursePalette =>
      ColorHex.coursePalette.map(ColorHex.parse).toList(growable: false);

  /// Theme-invariant foreground for filled accent surfaces that keep the
  /// same fill brightness in both themes (e.g. the green success button
  /// on the Notes screen, check marks on `success`).
  static const Color onAccent = Color(0xFFFFFFFF);

  static final _Palette _light = _Palette(
    bgApp: ColorHex.parse(ColorHex.bgApp),
    bgSurface: ColorHex.parse(ColorHex.bgSurface),
    bgSurface2: ColorHex.parse(ColorHex.bgSurface2),
    primary: ColorHex.parse(ColorHex.primary),
    primarySoft: ColorHex.parse(ColorHex.primarySoft),
    onPrimary: ColorHex.parse(ColorHex.onPrimary),
    onPrimaryContainer: ColorHex.parse(ColorHex.onPrimaryContainer),
    textMain: ColorHex.parse(ColorHex.textMain),
    textDim: ColorHex.parse(ColorHex.textDim),
    textFaint: ColorHex.parse(ColorHex.textFaint),
    divider: ColorHex.parse(ColorHex.divider),
    priorityCritical: ColorHex.parse(ColorHex.priorityCritical),
    priorityCriticalBg: ColorHex.parse(ColorHex.priorityCriticalBg),
    priorityHigh: ColorHex.parse(ColorHex.priorityHigh),
    priorityHighBg: ColorHex.parse(ColorHex.priorityHighBg),
    priorityMedium: ColorHex.parse(ColorHex.priorityMedium),
    priorityMediumBg: ColorHex.parse(ColorHex.priorityMediumBg),
    priorityLow: ColorHex.parse(ColorHex.priorityLow),
    priorityLowBg: ColorHex.parse(ColorHex.priorityLowBg),
    success: ColorHex.parse(ColorHex.success),
    statusColor: ColorHex.parse(ColorHex.statusColor),
  );

  static final _Palette _dark = _Palette(
    bgApp: ColorHex.parse(ColorHex.bgAppDark),
    bgSurface: ColorHex.parse(ColorHex.bgSurfaceDark),
    bgSurface2: ColorHex.parse(ColorHex.bgSurface2Dark),
    primary: ColorHex.parse(ColorHex.primaryDark),
    primarySoft: ColorHex.parse(ColorHex.primarySoftDark),
    onPrimary: ColorHex.parse(ColorHex.onPrimaryDark),
    onPrimaryContainer: ColorHex.parse(ColorHex.onPrimaryContainerDark),
    textMain: ColorHex.parse(ColorHex.textMainDark),
    textDim: ColorHex.parse(ColorHex.textDimDark),
    textFaint: ColorHex.parse(ColorHex.textFaintDark),
    divider: ColorHex.parse(ColorHex.dividerDark),
    priorityCritical: ColorHex.parse(ColorHex.priorityCriticalDark),
    priorityCriticalBg: ColorHex.parse(ColorHex.priorityCriticalBgDark),
    priorityHigh: ColorHex.parse(ColorHex.priorityHighDark),
    priorityHighBg: ColorHex.parse(ColorHex.priorityHighBgDark),
    priorityMedium: ColorHex.parse(ColorHex.priorityMediumDark),
    priorityMediumBg: ColorHex.parse(ColorHex.priorityMediumBgDark),
    priorityLow: ColorHex.parse(ColorHex.priorityLowDark),
    priorityLowBg: ColorHex.parse(ColorHex.priorityLowBgDark),
    success: ColorHex.parse(ColorHex.successDark),
    statusColor: ColorHex.parse(ColorHex.statusColorDark),
  );
}

class _Palette {
  final Color bgApp, bgSurface, bgSurface2, primary, primarySoft;
  final Color onPrimary, onPrimaryContainer;
  final Color textMain, textDim, textFaint, divider;
  final Color priorityCritical, priorityCriticalBg;
  final Color priorityHigh, priorityHighBg;
  final Color priorityMedium, priorityMediumBg;
  final Color priorityLow, priorityLowBg;
  final Color success, statusColor;

  const _Palette({
    required this.bgApp, required this.bgSurface, required this.bgSurface2,
    required this.primary, required this.primarySoft,
    required this.onPrimary, required this.onPrimaryContainer,
    required this.textMain, required this.textDim, required this.textFaint,
    required this.divider,
    required this.priorityCritical, required this.priorityCriticalBg,
    required this.priorityHigh, required this.priorityHighBg,
    required this.priorityMedium, required this.priorityMediumBg,
    required this.priorityLow, required this.priorityLowBg,
    required this.success, required this.statusColor,
  });
}