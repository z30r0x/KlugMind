// lib/features/home_page/home.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:klugmind/core/models/material_models.dart';
import 'package:klugmind/core/services/course_store.dart';
import 'package:klugmind/core/services/study_intake_service.dart';
import 'package:klugmind/core/utils/styles/colors.dart';
import 'package:klugmind/core/utils/styles/fonts.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/features/notes_page/notes.dart';
import 'package:klugmind/features/onboarding_page/onboarding.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _pastedSyllabusText;
  PlatformFile? _uploadedFile;
  XFile? _capturedPhoto;

  // Lazy: no platform channels are touched until a PDF/photo is read.
  final _intake = StudyIntakeService();
  RawMaterial? _raw;
  bool _extracting = false;
  int _job = 0; // guards against out-of-order async results

  @override
  void initState() {
    super.initState();
    CourseStore.courses.addListener(_onCoursesChanged);
  }

  @override
  void dispose() {
    CourseStore.courses.removeListener(_onCoursesChanged);
    _intake.dispose();
    super.dispose();
  }

  void _onCoursesChanged() {
    if (mounted) setState(() {});
  }

  /// Runs PDF text extraction / OCR and stores the result in [_raw].
  Future<void> _extract(Future<RawMaterial> Function() work) async {
    final job = ++_job;
    setState(() => _extracting = true);
    try {
      final raw = await work();
      if (!mounted || job != _job) return;
      setState(() {
        _raw = raw;
        _extracting = false;
      });
    } catch (e) {
      if (!mounted || job != _job) return;
      setState(() => _extracting = false);
      final msg = e is FormatException
          ? e.message
          : 'Could not read that file.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _addCourse() async {
    final name = await _promptCourseName(context);
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;
    if (!CourseStore.add(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That course is already on your list.')),
      );
    }
  }

  void _removeCourse(String id) => CourseStore.remove(id);

  Future<String?> _promptCourseName(BuildContext context) async {
    var name = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a course'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => name = value,
          decoration: const InputDecoration(hintText: 'Course name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(name),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPasteTextCard() async {
    final controller = TextEditingController(text: _pastedSyllabusText ?? '');
    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Paste syllabus text'),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 10,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: 'Paste or type your syllabus text here…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (!mounted) return;
    if (result == null || result.trim().isEmpty) return;
    final text = result.trim();
    _job++; // cancel any in-flight extraction
    setState(() {
      _pastedSyllabusText = text;
      _uploadedFile = null;
      _capturedPhoto = null;
      _extracting = false;
      _raw = RawMaterial(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        source: MaterialSource.typedText,
        extractedText: StudyIntakeService.sanitize(text),
        confidence: 1.0,
        capturedAt: DateTime.now(),
      );
    });
  }

  Future<void> _openFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      setState(() {
        _uploadedFile = file;
        _pastedSyllabusText = null;
        _capturedPhoto = null;
        _raw = null;
      });
      final path = file.path;
      if (path == null) return;
      _extract(
        () => path.toLowerCase().endsWith('.pdf')
            ? _intake.fromPdf(path)
            : _intake.fromPhoto(File(path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open file picker: $e')));
    }
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (photo == null) return;
      setState(() {
        _capturedPhoto = photo;
        _pastedSyllabusText = null;
        _uploadedFile = null;
        _raw = null;
      });
      _extract(() => _intake.fromPhoto(File(photo.path)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open camera: $e')));
    }
  }

  void _generateFlashcards() {
    final raw = _raw;
    if (raw == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NotesPage(initialRaw: raw)));
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingPage()),
    );
  }

  String? get _syllabusStatusLabel {
    final pasted = _pastedSyllabusText;
    if (pasted != null) {
      final preview = pasted.length > 40
          ? '${pasted.substring(0, 40)}…'
          : pasted;
      return 'Pasted text saved: "$preview"';
    }
    if (_uploadedFile != null) return 'File selected: ${_uploadedFile!.name}';
    if (_capturedPhoto != null) return 'Photo captured';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final status = _syllabusStatusLabel;
    final courses = CourseStore.courses.value;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          children: [
            PageTopBar(currentStep: 0, totalSteps: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set up KlugMind',
                      style: Fonts.h1Lg.copyWith(color: AppColors.textMain),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your courses so we can build your plan',
                      style: Fonts.sub.copyWith(color: AppColors.textDim),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Your courses',
                      style: Fonts.sectionLabel.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < courses.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CourseChip(
                          key: ValueKey(courses[i].id),
                          course: courses[i],
                          dotColor: AppColors.courseColor(i),
                          onRemove: () => _removeCourse(courses[i].id),
                        ),
                      ),
                    if (courses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No courses yet — add one to continue.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ),
                    _AddCourseButton(onTap: _addCourse),
                    const SizedBox(height: 24),
                    Text(
                      'Add a syllabus (optional)',
                      style: Fonts.sectionLabel.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SyllabusOptionCard(
                      icon: Icons.description_outlined,
                      title: 'Paste text',
                      subtitle: 'Copy/paste syllabus text directly',
                      onTap: _openPasteTextCard,
                    ),
                    const SizedBox(height: 10),
                    _SyllabusOptionCard(
                      icon: Icons.upload_file_outlined,
                      title: 'Upload PDF or photo',
                      subtitle: 'OCR extracts dates & deadlines',
                      onTap: _openFilePicker,
                    ),
                    const SizedBox(height: 10),
                    _SyllabusOptionCard(
                      icon: Icons.camera_alt_outlined,
                      title: 'Take a photo',
                      subtitle: 'Snap your printed syllabus',
                      onTap: _openCamera,
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_extracting || _raw != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _extracting ? null : _generateFlashcards,
                            child: Text(
                              _extracting
                                  ? 'Reading text…'
                                  : '✨ Generate flashcards',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: courses.isEmpty ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.divider,
                    disabledForegroundColor: AppColors.textFaint,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue to Plan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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

class _CourseChip extends StatelessWidget {
  const _CourseChip({
    super.key,
    required this.course,
    required this.dotColor,
    required this.onRemove,
  });
  final AppCourse course;
  final Color dotColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              course.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove ${course.name}',
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: AppColors.textFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCourseButton extends StatelessWidget {
  const _AddCourseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '+ Add another course',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

class _SyllabusOptionCard extends StatelessWidget {
  const _SyllabusOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textDim,
                      ),
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
