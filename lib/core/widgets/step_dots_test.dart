// test/step_dots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/widgets/step_dots.dart';

void main() {
  testWidgets('renders one segment per step', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StepDots(currentStep: 0, totalSteps: 3)),
    ));
    // 3 dot containers direct under the Row (ignore SizedBox spacers).
    expect(
      find.descendant(
          of: find.byType(StepDots), matching: find.byType(AnimatedContainer)),
      findsNWidgets(3),
    );
  });

  testWidgets('active step is widened and primary-colored', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StepDots(currentStep: 1, totalSteps: 3)),
    ));
    final containers = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    final widths = containers
        .map((c) => (c.constraints as BoxConstraints).maxWidth)
        .toList();
    expect(widths[1], greaterThan(widths[0]));
    expect(widths[1], greaterThan(widths[2]));
  });

  testWidgets('asserts on out-of-range currentStep', (tester) async {
    expect(
      () => StepDots(currentStep: 3, totalSteps: 3),
      throwsAssertionError,
    );
  });
}