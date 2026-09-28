// lib/core/widgets/step_dots.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';

/// Step-dot navigation indicator ("• • • •" with the active step
/// widened and primary-colored). Shared across every onboarding /
/// setup screen so it's one visual language and one place to change it.
///
/// Usage: `StepDots(currentStep: 0, totalSteps: 3)` where currentStep
/// is 0-indexed.
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  })  : assert(totalSteps > 0),
        assert(currentStep >= 0 && currentStep < totalSteps);

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: i == currentStep ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentStep ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (i != totalSteps - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}