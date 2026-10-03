import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../home/presentation/home_screen.dart';
import 'materials_controller.dart';
import 'courses.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  final String courseId;

  const MaterialsScreen({super.key, required this.courseId});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  String? _courseId;
  bool _generateSummary = true;
  bool _generateFlashcards = true;
  bool _generateQuiz = true;

  PlatformFile? _selectedFile;
  bool _picking = false;
  bool _submitting = false;

  Future<void> _pickFile() async {
    if (_picking ||
        _submitting ||
        ref.read(materialsControllerProvider).isLoading) {
      return;
    }
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'pptx'],
        withData: kIsWeb,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      final extension = file.extension?.toLowerCase();
      if (extension != 'pdf' && extension != 'pptx') {
        _showSelectionError('Pilih file PDF atau PPTX.');
        return;
      }
      if (file.size > 20 * 1024 * 1024) {
        _showSelectionError('Ukuran file maksimal 20 MB.');
        return;
      }
      if (file.bytes == null && (kIsWeb || file.path == null)) {
        _showSelectionError('File tidak dapat dibaca.');
        return;
      }
      setState(() => _selectedFile = file);
    } catch (_) {
      if (mounted) _showSelectionError('Gagal memilih dokumen.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showSelectionError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _analyzeFile() async {
    final file = _selectedFile;
    final courses = ref.read(coursesProvider).valueOrNull ?? [];
    final courseId = _courseId ?? widget.courseId;
    if (!validCourseSelection(courseId, courses)) {
      _showSelectionError('Pilih mata kuliah terlebih dahulu.');
      return;
    }
    if (file == null ||
        _picking ||
        _submitting ||
        ref.read(materialsControllerProvider).isLoading) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final success = await ref
          .read(materialsControllerProvider.notifier)
          .uploadMaterial(
            courseId: courseId,
            generateSummary: _generateSummary,
            generateFlashcards: _generateFlashcards,
            generateQuiz: _generateQuiz,
            bytes: file.bytes,
            filePath: kIsWeb || file.bytes != null ? null : file.path,
            fileName: file.name,
            fileType: file.extension!.toLowerCase(),
          );
      if (!mounted) return;
      if (success) {
        setState(() => _selectedFile = null);
        ref.invalidate(materialsListProvider);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(materialsControllerProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];
    final candidate = _courseId ?? widget.courseId;
    final selectedCourse = validCourseSelection(candidate, courses)
        ? candidate
        : null;
    const primary = Color(0xFF4F46E5);
    const heading = Color(0xFF111827);
    const secondary = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'MindSpark AI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: heading,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Text(
              ref.watch(courseUserProvider).valueOrNull == null
                  ? ''
                  : 'Mahasiswa',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: secondary,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unggah Materi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: heading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unggah slide atau dokumen untuk ringkasan instan dan kuis AI.',
              style: TextStyle(fontSize: 14, height: 1.45, color: secondary),
            ),
            const SizedBox(height: 18),
            coursesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(coursesProvider),
                child: const Text('Gagal memuat mata kuliah. Coba lagi'),
              ),
              data: (courses) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourse,
                    key: ValueKey(selectedCourse),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mata Kuliah'),
                    hint: const Text('Pilih mata kuliah'),
                    items: courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(
                              course.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: state.isLoading || _submitting
                        ? null
                        : (value) => setState(() => _courseId = value),
                  ),
                  if (courses.isEmpty)
                    const Text('Belum ada mata kuliah. Tambahkan dahulu.'),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: state.isLoading || _submitting
                  ? null
                  : () async {
                      final course = await showAddCourseDialog(context, ref);
                      if (mounted && course != null) {
                        setState(() => _courseId = course.id);
                      }
                    },
              icon: const Icon(Icons.add),
              label: const Text('Tambah baru'),
            ),
            const SizedBox(height: 18),
            _uploadBox(state.isLoading || _submitting || _picking, primary),
            if (state.isLoading) ...[
              const SizedBox(height: 14),
              _processingCard(primary),
            ],
            if (!state.isLoading &&
                ref.read(materialsControllerProvider.notifier).materialId !=
                    null) ...[
              Text(
                ref.read(materialsControllerProvider.notifier).status == 'done'
                    ? 'Analisis selesai'
                    : ref.read(materialsControllerProvider.notifier).message ??
                          'Materi belum selesai diproses',
              ),
              if (ref.read(materialsControllerProvider.notifier).status !=
                  'done')
                TextButton(
                  onPressed: () {
                    final controller = ref.read(
                      materialsControllerProvider.notifier,
                    );
                    if (controller.status == 'failed' ||
                        controller.status == 'uploaded') {
                      controller.retry();
                    } else {
                      controller.poll();
                    }
                  },
                  child: Text(
                    ref.read(materialsControllerProvider.notifier).status ==
                                'failed' ||
                            ref
                                    .read(materialsControllerProvider.notifier)
                                    .status ==
                                'uploaded'
                        ? 'Coba analisis lagi'
                        : 'Periksa status',
                  ),
                ),
            ],
            const SizedBox(height: 18),
            _optionsCard(primary),
            if (state.maybeWhen(
              error: (_, _) => true,
              orElse: () => false,
            )) ...[
              const SizedBox(height: 14),
              state.maybeWhen(
                error: (error, _) => _errorCard(error.toString()),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    state.isLoading ||
                        _submitting ||
                        _picking ||
                        _selectedFile == null ||
                        coursesAsync.isLoading ||
                        coursesAsync.hasError ||
                        selectedCourse == null
                    ? null
                    : _analyzeFile,
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: Text(
                  state.isLoading ? 'Memproses materi...' : 'Mulai Analisis',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadBox(bool loading, Color primary) => InkWell(
    onTap: loading ? null : _pickFile,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFBFDBFE),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_upload_outlined, color: primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFile?.name ?? 'Pilih file PDF atau PPTX',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedFile == null
                ? 'Klik untuk memilih dokumen\n(Maks. 20 MB)'
                : '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : _pickFile,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: Text(
              _selectedFile == null ? 'Pilih Dokumen' : 'Ganti Dokumen',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              minimumSize: const Size(130, 40),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _processingCard(Color primary) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: const Row(
      children: [
        CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4F46E5)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Mengunggah dan memproses materi...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _optionsCard(Color primary) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Opsi Hasil AI',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        _optionRow(
          Icons.article_outlined,
          'Ringkasan Eksekutif',
          primary,
          _generateSummary,
          (value) => setState(() => _generateSummary = value),
        ),
        _optionRow(
          Icons.style_outlined,
          'Maks. 10 Flashcards Cerdas',
          primary,
          _generateFlashcards,
          (value) => setState(() => _generateFlashcards = value),
        ),
        _optionRow(
          Icons.quiz_outlined,
          'Kuis Pemahaman',
          primary,
          _generateQuiz,
          (value) => setState(() => _generateQuiz = value),
        ),
      ],
    ),
  );

  Widget _optionRow(
    IconData icon,
    String label,
    Color primary,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
        Switch(
          value: value,
          onChanged: ref.watch(materialsControllerProvider).isLoading
              ? null
              : onChanged,
          activeThumbColor: primary,
        ),
      ],
    ),
  );

  Widget _errorCard(String error) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      error,
      style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
    ),
  );
}
