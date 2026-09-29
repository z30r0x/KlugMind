// lib/features/flashcards_page/flashcards.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';

enum CardRating { again, good, easy }

/// Flashcard study session: step dots + theme toggle on top, the card in
/// the middle, and the shared bottom navbar.
class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({
    super.key,
    required this.cards,
    required this.courseName,
    this.onFinished,
    this.streak = 12,
  });

  /// In-memory "current deck" until real persistence (Hive/Supabase) lands.
  /// Notes fills these on "Save & Start Studying"; the navbar reads them.
  static List<GeneratedFlashcard> lastDeck = const [];
  static String lastCourse = 'My Notes';

  final List<GeneratedFlashcard> cards;
  final String courseName;
  final ValueChanged<List<CardRating>>? onFinished;
  final int streak;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  int _index = 0;
  bool _revealed = false;
  final List<CardRating> _ratings = [];

  void _reveal() {
    if (!_revealed) setState(() => _revealed = true);
  }

  void _rate(CardRating r) {
    if (_ratings.length >= widget.cards.length) return;
    _ratings.add(r);
    final finished = _ratings.length == widget.cards.length;
    setState(() {
      if (!finished) {
        _index++;
        _revealed = false;
      }
    });
    if (finished) widget.onFinished?.call(List.unmodifiable(_ratings));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final cards = widget.cards;

    // Not `const` on purpose: a const instance would skip build() on a
    // theme toggle and keep the old colors (see AppBottomNav).
    if (cards.isEmpty) {
      // ignore: prefer_const_constructors
      return _Message(
          title: 'No cards to study',
          body: 'Generate some from your notes first.');
    }
    if (_ratings.length == cards.length) {
      int n(CardRating r) => _ratings.where((x) => x == r).length;
      return _Message(
        title: 'Session complete',
        body: '${cards.length} cards reviewed — '
            'Again ${n(CardRating.again)} · Good ${n(CardRating.good)} · '
            'Easy ${n(CardRating.easy)}',
      );
    }

    final card = cards[_index];
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      bottomNavigationBar: AppBottomNav(active: AppTab.flashcards),
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(currentStep: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(Icons.close, color: AppColors.textDim),
                        ),
                        Expanded(
                          child: Center(
                            child: Text('Card ${_index + 1} of ${cards.length}',
                                style: Fonts.sectionLabel
                                    .copyWith(color: AppColors.textDim)),
                          ),
                        ),
                        Icon(Icons.local_fire_department,
                            size: 18, color: AppColors.priorityHigh),
                        const SizedBox(width: 2),
                        Text('${widget.streak}',
                            style: Fonts.sectionLabel
                                .copyWith(color: AppColors.textMain)),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _index / cards.length,
                        minHeight: 4,
                        color: AppColors.primary,
                        backgroundColor: AppColors.divider,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _reveal,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(widget.courseName.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: Fonts.chip.copyWith(
                                            letterSpacing: 1,
                                            color: AppColors.onPrimary
                                                .withAlpha(191))),
                                    const SizedBox(height: 18),
                                    Text(card.question,
                                        textAlign: TextAlign.center,
                                        style: Fonts.h1.copyWith(
                                            fontSize: _revealed ? 18 : 24,
                                            color: AppColors.onPrimary)),
                                    const SizedBox(height: 18),
                                    if (_revealed) ...[
                                      Divider(
                                          color: AppColors.onPrimary
                                              .withAlpha(89)),
                                      const SizedBox(height: 12),
                                      Text(card.answer,
                                          textAlign: TextAlign.center,
                                          style: Fonts.bodyBold.copyWith(
                                              fontSize: 17,
                                              color: AppColors.onPrimary)),
                                    ] else
                                      Text('Tap to reveal answer',
                                          style: Fonts.caption.copyWith(
                                              color: AppColors.onPrimary
                                                  .withAlpha(191))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _RateButton(
                            label: 'Again',
                            fg: AppColors.priorityCritical,
                            bg: AppColors.priorityCriticalBg,
                            onTap: _revealed
                                ? () => _rate(CardRating.again)
                                : null),
                        const SizedBox(width: 10),
                        _RateButton(
                            label: 'Good',
                            fg: AppColors.priorityHigh,
                            bg: AppColors.priorityHighBg,
                            onTap:
                                _revealed ? () => _rate(CardRating.good) : null),
                        const SizedBox(width: 10),
                        _RateButton(
                            label: 'Easy',
                            fg: AppColors.priorityLow,
                            bg: AppColors.priorityLowBg,
                            onTap:
                                _revealed ? () => _rate(CardRating.easy) : null),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton(
      {required this.label,
      required this.fg,
      required this.bg,
      required this.onTap});
  final String label;
  final Color fg, bg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? .5 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(label,
                    style: Fonts.bodyBold.copyWith(fontSize: 14, color: fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty / finished state: top bar pinned at the top, message centered in
/// the space between the top bar and the navbar.
class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      bottomNavigationBar: AppBottomNav(active: AppTab.flashcards),
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(currentStep: 1),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          textAlign: TextAlign.center,
                          style:
                              Fonts.h1Lg.copyWith(color: AppColors.textMain)),
                      const SizedBox(height: 8),
                      Text(body,
                          textAlign: TextAlign.center,
                          style: Fonts.sub.copyWith(color: AppColors.textDim)),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}