import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_visuals.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../home/presentation/home_screen.dart';
import '../../materials/domain/material_model.dart';
import '../../materials/presentation/courses.dart';
import '../data/quiz_repository.dart';
import '../domain/quiz_model.dart';
import 'quiz_controller.dart';

final quizCourseProvider = StateProvider<String?>((ref) {
  ref.watch(courseUserProvider);
  return null;
});

class QuizHistoryEntry {
  const QuizHistoryEntry({
    required this.attempt,
    required this.materialId,
    required this.materialTitle,
  });

  final QuizAttemptModel attempt;
  final String materialId;
  final String materialTitle;
}

final quizHistoryAcrossMaterialsProvider =
    FutureProvider.autoDispose<List<QuizHistoryEntry>>((ref) async {
      final materials = await ref.watch(materialsListProvider.future);
      final repository = ref.watch(quizRepositoryProvider);
      final attemptsByMaterial = await Future.wait(
        materials.map((material) async {
          try {
            return await repository.getAttempts(material.id);
          } catch (_) {
            return <QuizAttemptModel>[];
          }
        }),
      );
      final entries = <QuizHistoryEntry>[];
      for (var index = 0; index < materials.length; index++) {
        final material = materials[index];
        entries.addAll(
          attemptsByMaterial[index].map(
            (attempt) => QuizHistoryEntry(
              attempt: attempt,
              materialId: material.id,
              materialTitle: material.title,
            ),
          ),
        );
      }
      entries.sort((a, b) {
        final aDate = a.attempt.createdAt;
        final bDate = b.attempt.createdAt;
        if (aDate == null) return bDate == null ? 0 : 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return entries;
    });

class QuizHubScreen extends ConsumerStatefulWidget {
  const QuizHubScreen({super.key});

  @override
  ConsumerState<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState extends ConsumerState<QuizHubScreen> {
  String? _selectedMaterialId;
  String _difficulty = 'sedang';
  int _amount = 10;

  static const _difficulties = [
    ('mudah', 'Mudah', 'Pemahaman dasar'),
    ('sedang', 'Sedang', 'Penerapan konsep'),
    ('sulit', 'Sulit', 'Analisis kasus'),
  ];

  Future<void> _startQuiz(MaterialModel material) async {
    await context.push<void>(
      '/materials/${material.id}/quiz'
      '?amount=$_amount&difficulty=$_difficulty&generate_new=true',
    );
    if (!mounted) return;
    ref.invalidate(quizProgressProvider);
    ref.invalidate(quizHistoryAcrossMaterialsProvider);
  }

  void _openReview(QuizHistoryEntry entry) {
    context.push<void>(
      '/quiz-attempts/${entry.attempt.id}/review?material_id=${entry.materialId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(materialsListProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final progressAsync = ref.watch(quizProgressProvider);
    final historyAsync = ref.watch(quizHistoryAcrossMaterialsProvider);
    final courses = coursesAsync.valueOrNull ?? const <Course>[];
    final allMaterials = materialsAsync.valueOrNull ?? const <MaterialModel>[];
    final selectedCourseId = ref.watch(quizCourseProvider);
    final availableMaterials = filterMaterials(
      allMaterials,
      selectedCourseId,
    ).where((material) => material.status == 'done').toList();
    final selectedMaterial = availableMaterials
        .where((material) => material.id == _selectedMaterialId)
        .firstOrNull;
    final effectiveMaterial =
        selectedMaterial ?? availableMaterials.firstOrNull;
    final history = historyAsync.valueOrNull ?? const <QuizHistoryEntry>[];
    final latestAttempt = history.firstOrNull;
    final progress = progressAsync.valueOrNull?.values ?? const [];
    final completedCount = progress.fold<int>(
      0,
      (total, item) => total + item.count,
    );
    final weightedScore = completedCount == 0
        ? null
        : progress.fold<double>(
                0,
                (total, item) => total + (item.meanScore ?? 0) * item.count,
              ) /
              completedCount;
    final bestScore = progress
        .map((item) => item.bestScore)
        .whereType<double>()
        .fold<double?>(
          null,
          (best, score) => best == null || score > best ? score : best,
        );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Kuis',
        subtitle: effectiveMaterial?.title ?? 'Pilih materi untuk mulai',
        showBackButton: false,
        actions: [
          _completedBadge(
            loading: progressAsync.isLoading,
            completed: completedCount,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(materialsListProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(quizProgressProvider);
          ref.invalidate(quizHistoryAcrossMaterialsProvider);
          await ref.read(materialsListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            const SizedBox(height: 2),
            _statsRow(
              average: weightedScore,
              best: bestScore,
              loading: progressAsync.isLoading,
            ),
            const SizedBox(height: 18),
            if (latestAttempt != null)
              _latestAttemptCard(latestAttempt)
            else
              _firstQuizCard(),
            const SizedBox(height: 20),
            _buildPracticeCard(
              coursesAsync: coursesAsync,
              courses: courses,
              materialsAsync: materialsAsync,
              materials: availableMaterials,
              selectedCourseId: selectedCourseId,
              selectedMaterial: effectiveMaterial,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat kuis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                if (history.isNotEmpty)
                  Text(
                    '${history.length} latihan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => _inlineRetry(
                'Riwayat kuis gagal dimuat.',
                () => ref.invalidate(quizHistoryAcrossMaterialsProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? _emptyHistory()
                  : Column(
                      children: [
                        for (final entry in entries) _historyCard(entry),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow({
    required double? average,
    required double? best,
    required bool loading,
  }) => Row(
    children: [
      Expanded(
        child: CutoutStatCard(
          label: 'Rata-rata skor',
          icon: Icons.bar_chart_rounded,
          peach: true,
          value: Text(
            loading ? '…' : average?.toStringAsFixed(0) ?? '—',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: CutoutStatCard(
          label: 'Skor terbaik',
          icon: Icons.emoji_events_outlined,
          value: Text(
            loading ? '…' : best?.toStringAsFixed(0) ?? '—',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );

  Widget _completedBadge({required bool loading, required int completed}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.peach,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '${loading ? '…' : completed} Selesai',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _latestAttemptCard(QuizHistoryEntry entry) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF0),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFF4D66C)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LATIHAN TERAKHIR',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracotta,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                entry.attempt.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.materialTitle} • Skor ${entry.attempt.score}/100',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => _openReview(entry),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.charcoal,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Hasil'),
        ),
      ],
    ),
  );

  Widget _firstQuizCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.peachSoft,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.peachBorder),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_rounded, color: AppColors.terracotta),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Siap mulai latihan?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Pilih materi dan atur kuis sesuai kebutuhanmu.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildPracticeCard({
    required AsyncValue<List<Course>> coursesAsync,
    required List<Course> courses,
    required AsyncValue<List<MaterialModel>> materialsAsync,
    required List<MaterialModel> materials,
    required String? selectedCourseId,
    required MaterialModel? selectedMaterial,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.borderLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mulai latihan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Pilih course'),
        const SizedBox(height: 7),
        coursesAsync.when(
          loading: () => _loadingField('Memuat course...'),
          error: (_, _) => _inlineRetry(
            'Course gagal dimuat.',
            () => ref.invalidate(coursesProvider),
          ),
          data: (_) => _dropdown<String>(
            value: selectedCourseId ?? '',
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua course')),
              for (final course in courses)
                DropdownMenuItem(value: course.id, child: Text(course.name)),
            ],
            onChanged: (value) {
              ref.read(quizCourseProvider.notifier).state =
                  value == null || value.isEmpty ? null : value;
              setState(() => _selectedMaterialId = null);
            },
          ),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Pilih materi'),
        const SizedBox(height: 7),
        materialsAsync.when(
          loading: () => _loadingField('Memuat materi...'),
          error: (_, _) => _inlineRetry(
            'Materi gagal dimuat.',
            () => ref.invalidate(materialsListProvider),
          ),
          data: (_) => _dropdown<String>(
            value: selectedMaterial?.id,
            hint: Text(
              materials.isEmpty ? 'Belum ada materi siap' : 'Pilih materi',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final material in materials)
                DropdownMenuItem(
                  value: material.id,
                  child: Text(
                    '${material.title}${material.title.toLowerCase().endsWith('.${material.fileType.toLowerCase()}') ? '' : '.${material.fileType.toLowerCase()}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: materials.isEmpty
                ? null
                : (value) => setState(() => _selectedMaterialId = value),
          ),
        ),
        const SizedBox(height: 17),
        _fieldLabel('Tingkat kesulitan'),
        const SizedBox(height: 8),
        for (final option in _difficulties) ...[
          _difficultyTile(option.$1, option.$2, option.$3),
          if (option != _difficulties.last) const SizedBox(height: 7),
        ],
        const SizedBox(height: 16),
        _fieldLabel('Jumlah soal'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final amount in const [5, 10, 15]) ...[
              Expanded(child: _amountChip(amount)),
              if (amount != 15) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: selectedMaterial == null
                ? null
                : () => _startQuiz(selectedMaterial),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Mulai kuis'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.inkMeta,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
  );

  Widget _loadingField(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(text, style: const TextStyle(color: AppColors.inkSecondary)),
  );

  Widget _dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    Widget? hint,
  }) => DropdownButtonFormField<T>(
    value: value,
    hint: hint,
    isExpanded: true,
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
    items: items,
    onChanged: onChanged,
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.borderLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.borderLine),
      ),
    ),
  );

  Widget _difficultyTile(String value, String title, String description) {
    final selected = _difficulty == value;
    return Material(
      color: selected ? AppColors.charcoal : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _difficulty = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: ' — $description',
                        style: TextStyle(
                          color: selected
                              ? Colors.white70
                              : AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: selected ? AppColors.peach : AppColors.inkMeta,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountChip(int amount) {
    final selected = _amount == amount;
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _amount = amount),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLine,
            ),
          ),
          child: Text(
            '$amount soal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(QuizHistoryEntry entry) {
    final scoreColor = entry.attempt.score >= 80
        ? const Color(0xFF087B59)
        : entry.attempt.score >= 60
        ? AppColors.terracotta
        : const Color(0xFFB54747);
    final date = entry.attempt.createdAt;
    final formattedDate = date == null
        ? 'Tanggal tidak tersedia'
        : '${date.day} ${_monthName(date.month)} ${date.year}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: const BorderSide(color: AppColors.borderLine),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => _openReview(entry),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.attempt.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.materialTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMeta,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${entry.attempt.score}/100',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkMeta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHistory() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderLine),
    ),
    child: const Text(
      'Belum ada kuis selesai. Hasil latihanmu akan muncul di sini.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.inkSecondary,
        height: 1.45,
      ),
    ),
  );

  Widget _inlineRetry(String text, VoidCallback onRetry) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.peachSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );

  String _monthName(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ][month - 1];
}
