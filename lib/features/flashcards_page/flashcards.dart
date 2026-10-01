import 'package:flutter/material.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'flashcard_view.dart';

class FlashcardsPage extends StatelessWidget {
  const FlashcardsPage({
    super.key,
    required this.cards,
    required this.courseName,
  });

  static List<GeneratedFlashcard> lastDeck = const [];
  static String lastCourse = 'My Notes';

  final List<GeneratedFlashcard> cards;
  final String courseName;

  void _startLearning(BuildContext context) {
    if (cards.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardSession(cards: cards, courseName: courseName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      bottomNavigationBar: AppBottomNav(active: AppTab.flashcards),
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flashcards',
                          style: Fonts.h1Lg.copyWith(color: AppColors.textMain),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$courseName · ${cards.length} cards',
                          style: Fonts.sub.copyWith(color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  if (cards.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => _startLearning(context),
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text('Start learning'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cards.isEmpty
                  ? Center(
                      child: Text(
                        'No cards yet',
                        style: Fonts.sub.copyWith(color: AppColors.textDim),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return Material(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Card ${index + 1}',
                                        style: Fonts.sectionLabel.copyWith(
                                          color: AppColors.textDim,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      card.difficulty,
                                      style: Fonts.caption.copyWith(
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  card.question,
                                  style: Fonts.bodyBold.copyWith(
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  card.answer,
                                  style: Fonts.sub.copyWith(
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _startLearning(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start learning'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
