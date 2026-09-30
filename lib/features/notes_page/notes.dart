// lib/features/notes_page/notes.dart
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/llm_service.dart' as llm;
import 'package:klugmind/core/services/study_store.dart';
import 'package:klugmind/core/services/study_intake_service.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/app_bottom_nav.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/features/flashcards_page/flashcards.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';
import 'package:klugmind/features/onboarding_page/widgets/study_task.dart';

/// Notes → study blocks (if the text has dates) or flashcards + quiz.
/// Typed text, camera photo (OCR) or device PDF -> StudyIntakeService ->
/// LLM -> preview -> Today page or FlashcardsPage.
class NotesPage extends StatefulWidget {
  const NotesPage({
    super.key,
    this.service,
    this.capturePhoto,
    this.pickPdf,
    this.onSaveAndStudy,
    this.courseName = 'My Notes',
    this.initialRaw,
  });

  final StudyIntakeService? service;
  final Future<File?> Function()? capturePhoto;
  final Future<String?> Function()? pickPdf;
  final VoidCallback? onSaveAndStudy;
  final String courseName;

  /// Text already extracted elsewhere (e.g. the home page).
  final RawMaterial? initialRaw;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _controller = TextEditingController();
  late final StudyIntakeService _service =
      widget.service ?? StudyIntakeService();
  RawMaterial? _raw;
  StructuredExtraction? _result;
  bool _loading = false;
  bool _lowConfidence = false;
  int? _downloadPct;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRaw;
    if (r != null) {
      _raw = r;
      _controller.text = r.extractedText;
      _lowConfidence = r.confidence < 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<File?> _defaultCapture() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 90);
    return x == null ? null : File(x.path);
  }

  Future<String?> _defaultPickPdf() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    return r?.files.single.path;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendly(Object e) {
    if (e is llm.HttpException ||
        e is TimeoutException ||
        e is SocketException) {
      return "Couldn't run the study model on this device. "
          'Check your connection for the first download.';
    }
    if (e is FormatException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  void _applyRaw(RawMaterial raw) {
    setState(() {
      _raw = raw;
      _result = null;
      _lowConfidence = raw.confidence < 0.5;
      _controller.text = raw.extractedText;
    });
  }

  Future<void> _onPdf() async {
    if (_loading) return;
    try {
      final path = await (widget.pickPdf ?? _defaultPickPdf)();
      if (path == null) return;
      final raw = await _service.fromPdf(path);
      if (!mounted) return;
      _applyRaw(raw);
    } catch (e) {
      debugPrint('pdf failed: $e');
      _toast(_friendly(e));
    }
  }

  Future<void> _onPhoto() async {
    if (_loading) return;
    try {
      final file = await (widget.capturePhoto ?? _defaultCapture)();
      if (file == null) return;
      final raw = await _service.fromPhoto(file);
      if (!mounted) return;
      _applyRaw(raw);
    } catch (e) {
      debugPrint('photo failed: $e');
      _toast(_friendly(e));
    }
  }

  Future<void> _generate() async {
    if (_loading) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _toast('Add notes, a PDF, or a photo first.');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      // First run downloads the on-device model; no-op afterwards.
      await _service.prepareModel(onProgress: (p) {
        if (mounted) setState(() => _downloadPct = p);
      });
      if (mounted) setState(() => _downloadPct = null);

      final base = _raw ??
          RawMaterial(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            source: MaterialSource.typedText,
            extractedText: text,
            confidence: 1.0,
            capturedAt: DateTime.now(),
          );
      final result = await _service.analyze(base.copyWith(extractedText: text));
      if (!mounted) return;
      final hasBlocks = StudyStore.blocksFrom(result.assignments).isNotEmpty;
      if (result.flashcards.isEmpty && !hasBlocks) {
        setState(() => _loading = false);
        _toast("Couldn't make cards from that. Edit the text and try again.");
        return;
      }
      setState(() {
        _loading = false;
        _result = result;
      });
    } catch (e) {
      debugPrint('generate failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _downloadPct = null;
      });
      _toast(_friendly(e));
    }
  }

  void _saveAndStudy() {
    final r = _result;
    if (r == null) return;

    // Keep the deck available on the Flashcards tab either way.
    if (r.flashcards.isNotEmpty) {
      FlashcardsPage.lastDeck = r.flashcards;
      FlashcardsPage.lastCourse = widget.courseName;
    }

    // Dated items -> study blocks on the Today page.
    final blocks = StudyStore.blocksFrom(r.assignments);
    if (blocks.isNotEmpty) {
      StudyStore.add(blocks);
      widget.onSaveAndStudy?.call();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
        (_) => false,
      );
      return;
    }

    // No dates -> flashcards.
    // TODO: persist deck (Hive/Supabase) before navigating.
    widget.onSaveAndStudy?.call();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          FlashcardsPage(cards: r.flashcards, courseName: widget.courseName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final result = _result;
    final blocks = result == null
        ? const <StudyTask>[]
        : StudyStore.blocksFrom(result.assignments);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      // Keep the navbar pinned to the bottom; the keyboard overlays it.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(currentStep: 1),
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('← Back to plan',
                      style: Fonts.sectionLabel.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDim,
                      )),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + keyboard),
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
                    TextField(
                      controller: _controller,
                      minLines: 6,
                      maxLines: null,
                      maxLength: StudyIntakeService.maxChars,
                      keyboardType: TextInputType.multiline,
                      cursorColor: AppColors.primary,
                      style: Fonts.sub
                          .copyWith(height: 1.3, color: AppColors.textMain),
                      decoration: InputDecoration(
                        hintText:
                            'Paste your notes here, or upload a PDF / take a photo of your notes…',
                        hintStyle: Fonts.sub
                            .copyWith(height: 1.3, color: AppColors.textFaint),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        counterText: '',
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
                    if (_lowConfidence) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.priorityHigh),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Low-confidence scan — check the text for OCR mistakes.',
                              style: Fonts.caption
                                  .copyWith(color: AppColors.priorityHigh),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _UploadButton(
                                label: 'Upload PDF', onTap: _onPdf)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _UploadButton(
                                label: 'Take photo', onTap: _onPhoto)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _GenerateButton(
                      loading: _loading,
                      label: _downloadPct == null
                          ? 'Generating…'
                          : 'Downloading model $_downloadPct%',
                      onTap: _generate,
                    ),
                    if (result != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 10),
                        child: Text('Preview — edit before saving',
                            style: Fonts.sectionLabel
                                .copyWith(color: AppColors.textDim)),
                      ),
                      if (blocks.isNotEmpty) ...[
                        for (final b in blocks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BlockPreview(task: b),
                          ),
                        const SizedBox(height: 8),
                        _SuccessButton(
                            label: 'Add to my plan', onTap: _saveAndStudy),
                      ] else ...[
                        _FlashPreview(
                            card: result.flashcards.first,
                            total: result.flashcards.length),
                        const SizedBox(height: 12),
                        _QuizRow(count: result.quizItems.length),
                        const SizedBox(height: 16),
                        _SuccessButton(
                            label: 'Save & Start Studying',
                            onTap: _saveAndStudy),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            AppBottomNav(active: AppTab.notes),
          ],
        ),
      ),
    );
  }
}

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
  const _GenerateButton(
      {required this.loading, required this.onTap, this.label = 'Generating…'});
  final bool loading;
  final String label;
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
                          Text(label, style: style),
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

class _BlockPreview extends StatelessWidget {
  const _BlockPreview({required this.task});
  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.timeRange,
              style: Fonts.caption.copyWith(color: AppColors.textFaint)),
          const SizedBox(height: 4),
          Text(task.title,
              style: Fonts.bodyBold.copyWith(color: AppColors.textMain)),
          Text(task.courseName,
              style: Fonts.caption.copyWith(color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _FlashPreview extends StatelessWidget {
  const _FlashPreview({required this.card, required this.total});
  final GeneratedFlashcard card;
  final int total;

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
            child: Text('FLASHCARD 1 OF $total',
                style: Fonts.chip.copyWith(
                    fontSize: 11, color: AppColors.onPrimaryContainer)),
          ),
          const SizedBox(height: 8),
          Text(
            card.question,
            style: Fonts.bodyBold.copyWith(
                fontSize: 15, height: 1.4, color: AppColors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _QuizRow extends StatelessWidget {
  const _QuizRow({required this.count});
  final int count;

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
          Text('$count-question quiz ready',
              style: Fonts.bodyBold
                  .copyWith(fontSize: 14, color: AppColors.textMain)),
        ],
      ),
    );
  }
}

class _SuccessButton extends StatelessWidget {
  const _SuccessButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

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