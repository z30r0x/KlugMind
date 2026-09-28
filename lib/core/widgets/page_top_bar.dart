// lib/core/widgets/page_top_bar.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/widgets/step_dots.dart';
import 'package:klugmind/core/widgets/theme_button.dart';

/// Shared top row: step dots (left) + theme toggle (right), both centered in
/// the same 26px-high row so they start at the same top level.
/// Constructor is intentionally NOT const (same reason as AppBottomNav):
/// a const instance would skip build() and freeze StepDots' theme colors.
class PageTopBar extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  PageTopBar({super.key, this.currentStep, this.totalSteps = 2});

  final int? currentStep;
  final int totalSteps;

  static const double height = 26;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (currentStep != null)
              StepDots(currentStep: currentStep!, totalSteps: totalSteps)
            else
              const SizedBox.shrink(),
            const ThemeButton(),
          ],
        ),
      ),
    );
  }
}