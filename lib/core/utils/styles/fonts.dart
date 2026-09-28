import 'package:flutter/material.dart';

/// Font family + text-style tokens, mirroring the prototype's Inter font
/// and `.h1` / `.h1-lg` / `.sub` / `.section-label` CSS classes.
///
/// Deliberately carries NO color. Typography (family/size/weight) and
/// color (light/dark tokens) are independent axes -- mixing them into one
/// signature is what caused the repeated `Colors` vs `AppColors` mix-ups.
/// Apply color at the call site:
///
/// ```dart
/// Text("Today's Plan", style: Fonts.h1.copyWith(color: c.textMain));
/// ```
///
/// Assumption: prototype loads Inter from Google Fonts via a <link> tag;
/// bundle Inter-*.ttf under assets/fonts/ and register it in pubspec.yaml
/// (see bottom of this file) rather than pulling in the google_fonts
/// package, to keep the app fully offline-capable like the rest of the
/// intake pipeline (OCR/voice run on-device, LLM is local via Ollama).
class Fonts {
  Fonts._();

  static const String family = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle h1Lg = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle sub = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.5,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
  );
}

/*
pubspec.yaml -- required for `family = 'Inter'` to resolve:

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-ExtraBold.ttf
          weight: 800
*/