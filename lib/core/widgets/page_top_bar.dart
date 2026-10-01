// lib/core/widgets/page_top_bar.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/widgets/step_dots.dart';
import 'package:klugmind/core/widgets/theme_button.dart';

/// Shared top row: step dots (left) + theme toggle (right), both centered in
/// the same 26px-high row so they start at the same top level.
/// Constructor is intentionally NOT const (same reason as AppBottomNav):
/// a const instance would skip build() and freeze StepDots' theme colors.
///
/// Steps: 0 Setup, 1 Today, 2 Notes, 3 Flashcards, 4 Profile.
class PageTopBar extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  PageTopBar({super.key, this.currentStep, this.totalSteps = 5});

  final int? currentStep;
  final int totalSteps;

  static const double height = 26;

  /// Last step any bar displayed; the next bar animates from it.
  static int? _lastStep;

  @override
  State<PageTopBar> createState() => _PageTopBarState();
}

class _PageTopBarState extends State<PageTopBar> {
  int? _shown;

  @override
  void initState() {
    super.initState();
    final target = widget.currentStep;
    if (target == null) return;
    final prev = PageTopBar._lastStep;
    _shown = (prev != null && prev >= 0 && prev < widget.totalSteps)
        ? prev
        : target;
    PageTopBar._lastStep = target;
    if (_shown != target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = widget.currentStep);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PageTopBar old) {
    super.didUpdateWidget(old);
    if (old.currentStep != widget.currentStep) {
      _shown = widget.currentStep;
      if (widget.currentStep != null) {
        PageTopBar._lastStep = widget.currentStep;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _shown;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SizedBox(
        height: PageTopBar.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (step != null)
              StepDots(currentStep: step, totalSteps: widget.totalSteps)
            else
              const SizedBox.shrink(),
            const ThemeButton(),
          ],
        ),
      ),
    );
  }
}