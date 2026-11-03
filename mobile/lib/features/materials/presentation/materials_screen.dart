import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_visuals.dart';
import '../../home/presentation/home_screen.dart';
import 'courses.dart';
import 'materials_controller.dart';

class MaterialsScreen extends ConsumerStatefulWidget {
  final String courseId;

  const MaterialsScreen({super.key, required this.courseId});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  String? _courseId;
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _picking = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
      setState(() {
        _selectedFile = file;
        if (_titleController.text.trim().isEmpty) {
          // Otomatis isi judul dari nama file tanpa ekstensi
          final nameWithoutExt = file.name.replaceAll(
            RegExp(r'\.[^./\\]+$'),
            '',
          );
          _titleController.text = nameWithoutExt;
        }
      });
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSelectionError('Isi judul materi terlebih dahulu.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final success = await ref
          .read(materialsControllerProvider.notifier)
          .uploadMaterial(
            courseId: courseId,
            title: title,
            generateSummary: true,
            generateFlashcards: true,
            generateQuiz: true,
            bytes: file.bytes,
            filePath: kIsWeb || file.bytes != null ? null : file.path,
            fileName: file.name,
            fileType: file.extension!.toLowerCase(),
          );
      if (!mounted) return;
      if (success) {
        setState(() {
          _selectedFile = null;
          _titleController.clear();
          _noteController.clear();
        });
        ref.invalidate(materialsListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Materi berhasil diunggah dan diproses!'),
          ),
        );
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
    final topInset = MediaQuery.paddingOf(context).top;

    final canSubmit =
        !state.isLoading &&
        !_submitting &&
        !_picking &&
        _selectedFile != null &&
        _titleController.text.trim().isNotEmpty &&
        !coursesAsync.isLoading &&
        !coursesAsync.hasError &&
        selectedCourse != null;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderLine, width: 1.5),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // JUDUL UTAMA & DESKRIPSI (Persis Referensi)
            const Text(
              'Upload materi',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tambahkan PDF atau PPTX untuk mulai belajar dengan AI.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // PILIH COURSE + TOMBOL BUAT COURSE BARU
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih course',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                TextButton(
                  onPressed: state.isLoading || _submitting
                      ? null
                      : () async {
                          final course = await showAddCourseDialog(
                            context,
                            ref,
                          );
                          if (mounted && course != null) {
                            setState(() => _courseId = course.id);
                          }
                        },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '+ Buat course baru',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // DROPDOWN COURSE
            coursesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(coursesProvider),
                child: const Text('Gagal memuat course. Coba lagi'),
              ),
              data: (courses) => DropdownButtonFormField<String>(
                initialValue: selectedCourse,
                key: ValueKey(selectedCourse),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder.copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                hint: const Text('Pilih mata kuliah'),
                items: courses
                    .map(
                      (course) => DropdownMenuItem(
                        value: course.id,
                        child: Text(
                          course.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: state.isLoading || _submitting
                    ? null
                    : (value) => setState(() => _courseId = value),
              ),
            ),
            const SizedBox(height: 20),

            // JUDUL MATERI INPUT
            const Text(
              'Judul materi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Contoh: Normalisasi Database',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // AREA FILE TERPILIH ATAU TOMBOL UPLOAD KOTAK
            if (_selectedFile == null)
              Material(
                color: AppColors.lavenderSoft,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: state.isLoading || _submitting || _picking
                      ? null
                      : _pickFile,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.lavenderBorder,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: AppColors.primaryDark,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pilih file PDF atau PPTX',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Klik untuk memilih dokumen (Maks. 20 MB)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: state.isLoading || _submitting || _picking
                              ? null
                              : _pickFile,
                          icon: const Icon(
                            Icons.folder_open_outlined,
                            size: 16,
                          ),
                          label: const Text('Pilih file'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.charcoal,
                            minimumSize: const Size(130, 42),
                            side: const BorderSide(color: AppColors.borderLine),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // KARTU FILE TERPILIH (Persis Gambar Referensi)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLine, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A16181D),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.lavenderSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _selectedFile!.extension?.toUpperCase() ?? 'PDF',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedFile!.extension?.toUpperCase() ?? 'PDF'} • ${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB • Siap diunggah',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _pickFile,
                      child: const Text(
                        'Ganti',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus file',
                      onPressed: () => setState(() => _selectedFile = null),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // CATATAN OPSIONAL (FOKUS BAB / TOPIK)
            const Text(
              'Catatan opsional (fokus bab/topik)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText:
                    'Contoh: Fokuskan ringkasan pada studi kasus 2NF dan 3NF...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMeta,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(18),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorder.copyWith(
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // STATUS LOADING / ERROR
            if (state.isLoading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.peach,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Sedang mengunggah dan memproses materi...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            if (state.maybeWhen(
              error: (_, _) => true,
              orElse: () => false,
            )) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.maybeWhen(
                    error: (e, _) => e.toString(),
                    orElse: () => 'Terjadi kesalahan.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // TOMBOL UTAMA "Upload materi" (Persis Desain Referensi)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: canSubmit ? _analyzeFile : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  disabledBackgroundColor: const Color(0xFFE2DDD5),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(
                  Icons.upload_file_rounded,
                  size: 20,
                  color: AppColors.peach,
                ),
                label: Text(
                  state.isLoading ? 'Mengunggah...' : 'Upload materi',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
