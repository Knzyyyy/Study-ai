import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../flashcard/presentation/flashcard_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../domain/material_model.dart';
import '../../quiz/presentation/quiz_controller.dart';
import '../../summary/presentation/summary_controller.dart';
import 'courses.dart';

class MaterialDetailScreen extends ConsumerWidget {
  const MaterialDetailScreen({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsListProvider);
    final courses = ref.watch(coursesProvider).valueOrNull ?? const <Course>[];
    final progress = ref.watch(quizProgressProvider);
    final reviews = ref.watch(flashcardsProvider(materialId));
    final summary = ref.watch(summaryProvider(materialId));
    final material = materials.valueOrNull
        ?.where((item) => item.id == materialId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Detail materi',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            tooltip: 'Muat ulang detail',
            onPressed: () {
              ref.invalidate(materialsListProvider);
              ref.invalidate(quizProgressProvider);
              ref.invalidate(flashcardsProvider(materialId));
              ref.invalidate(summaryProvider(materialId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: material == null
          ? materials.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(
                child: Text('Detail materi belum dapat dimuat.'),
              ),
              data: (_) => const Center(child: Text('Materi tidak ditemukan.')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                _documentCard(
                  material: material,
                  courseName: courses
                      .where((course) => course.id == material.courseId)
                      .firstOrNull
                      ?.name,
                ),
                const SizedBox(height: 18),
                _progressCard(
                  status: material.status,
                  score: progress.valueOrNull?[materialId]?.latestScore,
                  flashcardCount: reviews.valueOrNull?.length,
                  summaryReady: summary.hasValue,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Belajar dengan AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _actionCard(
                      context,
                      title: 'Ringkasan AI',
                      subtitle: 'Pahami inti materi',
                      icon: Icons.description_outlined,
                      enabled: material.status == 'done',
                      onTap: () =>
                          context.push('/materials/$materialId/summary'),
                    ),
                    _actionCard(
                      context,
                      title: 'Flashcard',
                      subtitle: 'Ulangi konsep penting',
                      icon: Icons.layers_outlined,
                      enabled: material.status == 'done',
                      onTap: () =>
                          context.push('/materials/$materialId/flashcards'),
                    ),
                    _actionCard(
                      context,
                      title: 'Kuis',
                      subtitle: 'Uji pemahamanmu',
                      icon: Icons.assignment_outlined,
                      enabled: material.status == 'done',
                      onTap: () => context.push('/materials/$materialId/quiz'),
                    ),
                    _actionCard(
                      context,
                      title: 'Tanya AI Tutor',
                      subtitle: 'Diskusikan materi ini',
                      icon: Icons.chat_bubble_outline_rounded,
                      enabled: material.status == 'done',
                      dark: true,
                      onTap: () => context.push('/materials/$materialId/chat'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderLine),
                  ),
                  child: Text(
                    material.status == 'done'
                        ? 'Materi siap dipelajari. Pilih salah satu fitur belajar di atas.'
                        : material.status == 'failed'
                        ? material.errorMessage ?? 'Materi gagal diproses.'
                        : 'Materi sedang diproses. Fitur belajar akan tersedia setelah selesai.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _documentCard({
    required MaterialModel material,
    required String? courseName,
  }) {
    final isReady = material.status == 'done';
    final date = material.createdAt;
    final title =
        material.title.toLowerCase().endsWith(
          '.${material.fileType.toLowerCase()}',
        )
        ? material.title
        : '${material.title}.${material.fileType.toLowerCase()}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.lavenderSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.primaryDark,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _tag(material.fileType.toUpperCase()),
                        if (courseName != null) _tag(courseName),
                        _tag(isReady ? 'Siap dipelajari' : 'Diproses'),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${material.fileType.toUpperCase()} • ${material.pageCount == null ? 'Jumlah halaman belum tersedia' : '${material.pageCount} halaman'} • Diunggah ${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard({
    required String status,
    required double? score,
    required int? flashcardCount,
    required bool summaryReady,
  }) {
    final ready = status == 'done';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.progressSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.progressBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progres belajar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                ready
                    ? 'Siap'
                    : status == 'failed'
                    ? 'Gagal'
                    : 'Diproses',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ready
                  ? 1
                  : status == 'failed'
                  ? 0
                  : null,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.terracotta,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _progressMetric('Ringkasan', summaryReady ? 'Siap' : '—'),
              const SizedBox(width: 8),
              _progressMetric(
                'Flashcard',
                flashcardCount == null ? '—' : '$flashcardCount kartu',
              ),
              const SizedBox(width: 8),
              _progressMetric(
                'Kuis',
                score == null
                    ? 'Belum dicoba'
                    : 'Skor ${score.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressMetric(String title, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMeta),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool dark = false,
  }) => Material(
    color: dark ? AppColors.charcoal : Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: dark ? AppColors.charcoal : AppColors.borderLine,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 23,
              color: dark ? AppColors.peach : AppColors.primaryDark,
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              enabled ? subtitle : 'Tersedia setelah materi siap',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: dark ? Colors.white70 : AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.lavenderSoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      ),
    ),
  );
}
