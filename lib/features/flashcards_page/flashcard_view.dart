import 'package:flutter/material.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/theme_button.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';

enum CardRating { again, good, easy }

class FlashcardSession extends StatefulWidget {
  const FlashcardSession({
    super.key,
    required this.cards,
    required this.courseName,
    this.streak = 12,
    this.onFinished,
  });

  final List<GeneratedFlashcard> cards;
  final String courseName;
  final int streak;
  final ValueChanged<List<CardRating>>? onFinished;

  @override
  State<FlashcardSession> createState() => _FlashcardSessionState();
}

class _FlashcardSessionState extends State<FlashcardSession> {
  final PageController _pageController = PageController();
  final Map<int, CardRating> _ratings = {};
  int _currentIndex = 0;
  bool _revealed = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _backToPlan() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      (_) => false,
    );
  }

  void _rate(CardRating rating) {
    _ratings[_currentIndex] = rating;
    int? nextIndex;
    for (var i = 0; i < widget.cards.length; i++) {
      if (!_ratings.containsKey(i)) {
        nextIndex = i;
        break;
      }
    }
    if (nextIndex == null) {
      setState(() => _revealed = false);
      widget.onFinished?.call(
        List.unmodifiable([
          for (var i = 0; i < widget.cards.length; i++) _ratings[i]!,
        ]),
      );
      return;
    }
    setState(() => _revealed = false);
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlashcardView(
      cards: widget.cards,
      courseName: widget.courseName,
      currentIndex: _currentIndex,
      streak: widget.streak,
      revealed: _revealed,
      sessionComplete:
          widget.cards.isNotEmpty && _ratings.length == widget.cards.length,
      pageController: _pageController,
      onPageChanged: (index) => setState(() {
        _currentIndex = index;
        _revealed = false;
      }),
      onReveal: () {
        if (!_revealed) setState(() => _revealed = true);
      },
      onAgain: () => _rate(CardRating.again),
      onGood: () => _rate(CardRating.good),
      onEasy: () => _rate(CardRating.easy),
      onClose: _backToPlan,
      onBackToPlan: _backToPlan,
    );
  }
}

class FlashcardView extends StatelessWidget {
  const FlashcardView({
    super.key,
    required this.cards,
    required this.courseName,
    required this.currentIndex,
    required this.streak,
    required this.revealed,
    required this.sessionComplete,
    required this.pageController,
    required this.onPageChanged,
    required this.onReveal,
    required this.onAgain,
    required this.onGood,
    required this.onEasy,
    required this.onClose,
    required this.onBackToPlan,
  });

  final List<GeneratedFlashcard> cards;
  final String courseName;
  final int currentIndex;
  final int streak;
  final bool revealed;
  final bool sessionComplete;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onReveal;
  final VoidCallback onAgain;
  final VoidCallback onGood;
  final VoidCallback onEasy;
  final VoidCallback onClose;
  final VoidCallback onBackToPlan;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final cardColor = AppColors.primary;
    final progress = cards.isEmpty
        ? 0.0
        : sessionComplete
        ? 1.0
        : (currentIndex + 1) / cards.length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            children: [
              _SessionHeader(
                cardLabel: cards.isEmpty
                    ? ''
                    : 'Card ${sessionComplete ? cards.length + 1 : currentIndex + 1} of ${cards.length}',
                streak: streak,
                showStreak: cards.isNotEmpty,
                onClose: onClose,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: cardColor,
                  backgroundColor: AppColors.divider,
                ),
              ),
              const SizedBox(height: 12),
              if (cards.isEmpty)
                Expanded(child: _EmptyState(onBack: onBackToPlan))
              else if (sessionComplete)
                Expanded(child: _CompleteState(onBackToPlan: onBackToPlan))
              else
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: cards.length,
                          onPageChanged: onPageChanged,
                          itemBuilder: (context, index) => _FlashcardSurface(
                            card: cards[index],
                            courseName: courseName,
                            cardColor: cardColor,
                            revealed: revealed && index == currentIndex,
                            onReveal: onReveal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _RatingButton(
                            label: 'Again',
                            foreground: AppColors.priorityCritical,
                            background: AppColors.priorityCriticalBg,
                            onPressed: revealed ? onAgain : null,
                          ),
                          const SizedBox(width: 8),
                          _RatingButton(
                            label: 'Good',
                            foreground: AppColors.priorityHigh,
                            background: AppColors.priorityHighBg,
                            onPressed: revealed ? onGood : null,
                          ),
                          const SizedBox(width: 8),
                          _RatingButton(
                            label: 'Easy',
                            foreground: AppColors.priorityLow,
                            background: AppColors.priorityLowBg,
                            onPressed: revealed ? onEasy : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.cardLabel,
    required this.streak,
    required this.showStreak,
    required this.onClose,
  });

  final String cardLabel;
  final int streak;
  final bool showStreak;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              onPressed: onClose,
              icon: Icon(Icons.close, size: 19, color: AppColors.textDim),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                cardLabel,
                style: Fonts.caption.copyWith(color: AppColors.textDim),
              ),
            ),
          ),
          if (showStreak) ...[
            Icon(
              Icons.local_fire_department,
              size: 16,
              color: AppColors.priorityHigh,
            ),
            const SizedBox(width: 2),
            Text(
              '$streak',
              style: Fonts.caption.copyWith(color: AppColors.textMain),
            ),
            const SizedBox(width: 8),
          ],
          const ThemeButton(),
        ],
      ),
    );
  }
}

class _FlashcardSurface extends StatelessWidget {
  const _FlashcardSurface({
    required this.card,
    required this.courseName,
    required this.cardColor,
    required this.revealed,
    required this.onReveal,
  });

  final GeneratedFlashcard card;
  final String courseName;
  final Color cardColor;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: revealed ? AppColors.success : cardColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onReveal,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    courseName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Fonts.chip.copyWith(
                      color: Colors.white.withAlpha(191),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    revealed ? card.answer : card.question,
                    textAlign: TextAlign.center,
                    style: Fonts.h1.copyWith(
                      fontSize: 21,
                      height: 1.18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    revealed
                        ? 'Rate how well you knew this'
                        : 'Tap to reveal answer',
                    style: Fonts.caption.copyWith(
                      color: Colors.white.withAlpha(191),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: onPressed == null ? 0.58 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(
                  label,
                  style: Fonts.bodyBold.copyWith(
                    fontSize: 13.5,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteState extends StatelessWidget {
  const _CompleteState({required this.onBackToPlan});

  final VoidCallback onBackToPlan;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.priorityLowBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Icon(Icons.check, color: AppColors.success, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Session complete',
              textAlign: TextAlign.center,
              style: Fonts.bodyBold.copyWith(
                fontSize: 16,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Next review dates have been scheduled with spaced repetition.',
              textAlign: TextAlign.center,
              style: Fonts.caption.copyWith(color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBackToPlan,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Back to plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No cards to study',
            style: Fonts.h1Lg.copyWith(color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate some from your notes first.',
            textAlign: TextAlign.center,
            style: Fonts.sub.copyWith(color: AppColors.textDim),
          ),
          const SizedBox(height: 18),
          TextButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}
