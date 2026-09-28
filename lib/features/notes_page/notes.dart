// lib/features/notes_page/notes.dart
import 'package:flutter/material.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';

/// "Notes → Flashcards & Quiz" screen (prototype: #screen-notes).
/// Paste notes / upload a file, tap Generate, review the preview, then
/// "Save & Start Studying".
class NotesPage extends StatefulWidget {
  const NotesPage({super.key, this.onSaveAndStudy, this.onGenerate});

  /// "Save & Start Studying" tap (prototype: goTo('study')).
  final VoidCallback? onSaveAndStudy;

  /// Optional real generation hook; receives the notes text. When null the
  /// prototype's 1-second fake delay is used.
  final Future<void> Function(String notes)? onGenerate;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _showPreview = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    if (widget.onGenerate != null) {
      await widget.onGenerate!(_controller.text);
    } else {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _showPreview = true;
    });
  }

  void _onNavSelect(AppTab tab) {
    switch (tab) {
      case AppTab.today:
        Navigator.of(context).maybePop();
      case AppTab.notes:
        return;
      case AppTab.profile:
        // TODO: navigate to Profile once that page exists.
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            // .back-row
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '← Back to plan',
                    style: Fonts.sectionLabel.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
              ),
            ),

            // .scroll-area (padding: 0 24px 20px)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes → Flashcards & Quiz',
                        style: Fonts.h1.copyWith(color: AppColors.textMain)),
                    const SizedBox(height: 4),
                    Text(
                      "Paste notes or upload a file — we'll generate cards",
                      style: Fonts.sub.copyWith(color: AppColors.textDim),
                    ),
                    const SizedBox(height: 16),

                    // textarea.notes-input
                    TextField(
                      controller: _controller,
                      minLines: 6,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      cursorColor: AppColors.primary,
                      style: Fonts.sub.copyWith(
                        height: 1.3,
                        color: AppColors.textMain,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Paste your notes here, or drag a PDF / photo of your notes into this box…',
                        hintStyle: Fonts.sub.copyWith(
                          height: 1.3,
                          color: AppColors.textFaint,
                        ),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // .upload-row
                    Row(
                      children: [
                        Expanded(
                            child: _UploadButton(
                                label: 'Upload PDF', onTap: () {})),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _UploadButton(
                                label: 'Take photo', onTap: () {})),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _GenerateButton(loading: _loading, onTap: _generate),

                    // .preview-wrap
                    if (_showPreview) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 10),
                        child: Text('Preview — edit before saving',
                            style: Fonts.sectionLabel
                                .copyWith(color: AppColors.textDim)),
                      ),
                      const _FlashPreview(),
                      const SizedBox(height: 12),
                      const _QuizRow(),
                      const SizedBox(height: 16),
                      _SuccessButton(
                        label: 'Save & Start Studying',
                        onTap: widget.onSaveAndStudy,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            AppBottomNav(active: AppTab.notes, onSelect: _onNavSelect),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Center(
            child: Text(label,
                style: Fonts.sectionLabel
                    .copyWith(color: AppColors.onPrimaryContainer)),
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Fonts.bodyBold.copyWith(color: AppColors.onPrimary);
    return Opacity(
      opacity: loading ? .5 : 1,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onTap,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Center(
                child: loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                              backgroundColor:
                                  AppColors.onPrimary.withAlpha(102),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Generating…', style: style),
                        ],
                      )
                    : Text('✨ Generate Flashcards + Quiz', style: style),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashPreview extends StatelessWidget {
  const _FlashPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: .75,
            child: Text('FLASHCARD 1 OF 10',
                style: Fonts.chip
                    .copyWith(fontSize: 11, color: AppColors.onPrimaryContainer)),
          ),
          const SizedBox(height: 8),
          Text(
            'What does SN2 stand for and what determines its rate?',
            style: Fonts.bodyBold.copyWith(
              fontSize: 15,
              height: 1.4,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.priorityMediumBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('📝', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('5-question quiz ready',
                  style: Fonts.bodyBold
                      .copyWith(fontSize: 14, color: AppColors.textMain)),
              const SizedBox(height: 1),
              Text('Covers reaction mechanisms',
                  style: Fonts.caption.copyWith(color: AppColors.textFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessButton extends StatelessWidget {
  const _SuccessButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.success,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Center(
              child: Text(label,
                  style: Fonts.bodyBold.copyWith(color: AppColors.onAccent)),
            ),
          ),
        ),
      ),
    );
  }
}