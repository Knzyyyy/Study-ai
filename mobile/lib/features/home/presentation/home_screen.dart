import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../materials/domain/material_model.dart';
import '../../materials/presentation/courses.dart';
import '../../quiz/domain/quiz_model.dart';
import '../../quiz/presentation/quiz_controller.dart';
import '../../flashcard/presentation/flashcard_controller.dart';
import '../../profile/presentation/profile_screen.dart' show weightedQuizScore;

final homeUserProvider = StreamProvider<User?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser;
  yield* auth.onAuthStateChange.map((event) => event.session?.user);
});

String homeUserName(User? user) {
  for (final value in [
    user?.userMetadata?['full_name'],
    user?.userMetadata?['name'],
    user?.email,
  ]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return 'Pengguna';
}

List<MaterialModel> latestHomeMaterials(List<MaterialModel> materials) =>
    (List<MaterialModel>.of(
      materials,
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(3).toList();

class HomeStatistics extends ConsumerWidget {
  const HomeStatistics({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsListProvider);
    final reviews = ref.watch(flashcardReviewCountProvider);
    final quizzes = ref.watch(quizProgressProvider);
    Widget metric(
      String label,
      IconData icon,
      AsyncValue<String> value,
      VoidCallback retry,
    ) => Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4F46E5), size: 22),
            const SizedBox(height: 6),
            value.when(
              skipLoadingOnRefresh: false,
              data: (text) => Text(
                text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              loading: () => const Text('Memuat...'),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tidak tersedia'),
                  TextButton(onPressed: retry, child: const Text('Coba lagi')),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
    final cards = [
      metric(
        'Materi diunggah',
        Icons.menu_book_outlined,
        materials.whenData((items) => '${items.length}'),
        () => ref.invalidate(materialsListProvider),
      ),
      metric(
        'Flashcard unik direview',
        Icons.style_outlined,
        reviews.whenData((count) => '$count'),
        () => ref.invalidate(flashcardReviewCountProvider),
      ),
      metric(
        'Rata-rata skor kuis',
        Icons.track_changes_rounded,
        quizzes.whenData((items) {
          final score = weightedQuizScore(items.values);
          return score == null
              ? 'Belum latihan'
              : '${score.toStringAsFixed(1)}%';
        }),
        () => ref.invalidate(quizProgressProvider),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            SizedBox(width: (constraints.maxWidth - 20) / 3, child: card),
        ],
      ),
    );
  }
}

({int total, int practiced, double? mean, int unknownDates}) courseProgress(
  Iterable<MaterialModel> materials,
  Map<String, QuizProgressModel> progress,
) {
  var total = 0;
  var practiced = 0;
  var unknownDates = 0;
  var sum = 0.0;
  var scores = 0;
  for (final material in materials) {
    total++;
    final item = progress[material.id];
    if (item == null || item.count == 0) continue;
    if (item.count < 0) throw const FormatException('Invalid attempt count');
    practiced++;
    if (item.lastPracticedAt == null) unknownDates++;
    final score = item.latestScore;
    if (score == null) continue;
    if (!score.isFinite || score < 0 || score > 100) {
      throw const FormatException('Invalid latest score');
    }
    sum += score;
    scores++;
  }
  return (
    total: total,
    practiced: practiced,
    mean: scores == practiced && scores > 0 ? sum / scores : null,
    unknownDates: unknownDates,
  );
}

class CourseProgressCard extends ConsumerWidget {
  final List<MaterialModel> materials;
  const CourseProgressCard({super.key, required this.materials});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10, bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ref
        .watch(quizProgressProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Text('Memuat progres mata kuliah...'),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(quizProgressProvider),
            child: const Text('Gagal memuat progres. Coba lagi'),
          ),
          data: (items) {
            try {
              final value = courseProgress(materials, items);
              return Text(
                '${value.practiced}/${value.total} materi dilatih • '
                'Rata-rata skor terbaru: ${value.mean?.toStringAsFixed(1) ?? "—"}${value.mean == null ? "" : "%"}'
                '\n${value.practiced == 0 ? "Belum latihan" : "Hanya materi dilatih; skor terbaru tidak lengkap ditampilkan —"}'
                '${value.unknownDates == 0 ? "" : "\nTanggal terbaru tidak tersedia: ${value.unknownDates} materi"}',
              );
            } on FormatException {
              return TextButton(
                onPressed: () => ref.invalidate(quizProgressProvider),
                child: const Text('Progres tidak valid. Coba lagi'),
              );
            }
          },
        ),
  );
}

final selectedCourseProvider = StateProvider<String?>((ref) {
  ref.watch(courseUserProvider);
  return null;
});

List<MaterialModel> filterMaterials(
  List<MaterialModel> materials,
  String? courseId,
) => courseId == null
    ? materials
    : materials.where((item) => item.courseId == courseId).toList();

final materialsListProvider = FutureProvider<List<MaterialModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = ref.watch(courseUserProvider).valueOrNull;

  if (userId == null) return [];

  final response = await supabase
      .from('materials')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  return response.map((json) => MaterialModel.fromJson(json)).toList();
});

class MaterialsLibraryScreen extends StatelessWidget {
  const MaterialsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen(materialsOnly: true);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.materialsOnly = false});

  final bool materialsOnly;

  Future<void> _deleteMaterial(
    BuildContext context,
    WidgetRef ref,
    MaterialModel material,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus materi?'),
        content: Text('File ${material.title} akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from('materials').remove([material.filePath]);
      await supabase.from('materials').delete().eq('id', material.id);
      ref.invalidate(materialsListProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus materi: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsListProvider);
    final name = homeUserName(ref.watch(homeUserProvider).valueOrNull);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    const primary = Color(0xFF4F46E5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const surface = Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              materialsOnly ? 'Materi' : 'Halo, $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Siap belajar hal baru hari ini?',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buka profil',
            icon: CircleAvatar(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: primary,
              child: Text(name.characters.first.toUpperCase()),
            ),
            onPressed: () => context.go('/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: reducedMotion ? 1 : 0, end: 1),
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 240),
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(quizProgressProvider);
            ref.invalidate(flashcardReviewCountProvider);
            final refreshed = ref.refresh(materialsListProvider.future);
            await refreshed;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: materialsOnly ? 20 : 28,
              bottom: materialsOnly ? 24 : 64,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!materialsOnly) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belajar lebih terarah',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Unggah materi, pahami ringkasan, lalu uji pemahamanmu.',
                                style: TextStyle(
                                  color: Color(0xFFE0E7FF),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              materialsAsync.when(
                                data: (materials) => ref
                                    .watch(quizProgressProvider)
                                    .when(
                                      data: (progress) {
                                        final practiced = materials
                                            .where(
                                              (material) =>
                                                  (progress[material.id]
                                                          ?.count ??
                                                      0) >
                                                  0,
                                            )
                                            .length;
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$practiced/${materials.length} materi dilatih',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(
                                              value: materials.isEmpty
                                                  ? 0
                                                  : practiced /
                                                        materials.length,
                                              backgroundColor: const Color(
                                                0xFF6366F1,
                                              ),
                                              color: Colors.white,
                                              minHeight: 6,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ],
                                        );
                                      },
                                      loading: () => const Text(
                                        'Memuat progres...',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      error: (_, _) => TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => ref.invalidate(
                                          quizProgressProvider,
                                        ),
                                        child: const Text(
                                          'Gagal memuat progres. Coba lagi',
                                        ),
                                      ),
                                    ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primary,
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => context.go(
                                  '/materials/upload/${Uri.encodeComponent(ref.read(selectedCourseProvider) ?? 'course-123')}',
                                ),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Upload materi'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Statistik belajar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const HomeStatistics(),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        materialsOnly ? 'Semua materi' : 'Materi terbaru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => showAddCourseDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Mata Kuliah'),
                      ),
                      ref
                          .watch(coursesProvider)
                          .when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => TextButton(
                              onPressed: () => ref.invalidate(coursesProvider),
                              child: const Text(
                                'Gagal memuat mata kuliah. Coba lagi',
                              ),
                            ),
                            data: (courses) => SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('Semua'),
                                    selected:
                                        ref.watch(selectedCourseProvider) ==
                                        null,
                                    onSelected: (_) =>
                                        ref
                                                .read(
                                                  selectedCourseProvider
                                                      .notifier,
                                                )
                                                .state =
                                            null,
                                  ),
                                  for (final course in courses)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: ChoiceChip(
                                        label: Text(course.name),
                                        selected:
                                            ref.watch(selectedCourseProvider) ==
                                            course.id,
                                        onSelected: (_) =>
                                            ref
                                                    .read(
                                                      selectedCourseProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                course.id,
                                      ),
                                    ),
                                  if (courses.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text('Belum ada mata kuliah'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      if (ref.watch(selectedCourseProvider) != null &&
                          validCourseSelection(
                            ref.watch(selectedCourseProvider),
                            ref.watch(coursesProvider).valueOrNull ?? [],
                          ))
                        materialsAsync.when(
                          data: (items) => CourseProgressCard(
                            materials: filterMaterials(
                              items,
                              ref.watch(selectedCourseProvider),
                            ),
                          ),
                          loading: () => const Text('Memuat materi...'),
                          error: (_, _) => TextButton(
                            onPressed: () =>
                                ref.invalidate(materialsListProvider),
                            child: const Text('Gagal memuat materi. Coba lagi'),
                          ),
                        ),
                    ],
                  ),
                ),
                materialsAsync.when(
                  skipLoadingOnRefresh: false,
                  data: (allMaterials) {
                    final selected = ref.watch(selectedCourseProvider);
                    final courses =
                        ref.watch(coursesProvider).valueOrNull ?? [];
                    final filtered = filterMaterials(
                      allMaterials,
                      validCourseSelection(selected, courses) ? selected : null,
                    );
                    final materials = materialsOnly
                        ? filtered
                        : latestHomeMaterials(filtered);
                    if (materials.isEmpty) {
                      return _emptyState(context, primary);
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final material = materials[index];
                        final isDone = material.status == 'done';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      material.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(material.status),
                                  IconButton(
                                    tooltip: 'Hapus materi',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFEF4444),
                                    ),
                                    onPressed: () =>
                                        _deleteMaterial(context, ref, material),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${material.fileType.toUpperCase()}${material.pageCount == null ? '' : '  •  ${material.pageCount} halaman'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _actionButton(
                                    context,
                                    Icons.article_outlined,
                                    'Ringkasan',
                                    isDone,
                                    () => context.push(
                                      '/materials/${material.id}/summary',
                                    ),
                                    primary,
                                  ),
                                  _actionButton(
                                    context,
                                    Icons.style_outlined,
                                    'Flashcard',
                                    isDone,
                                    () => context.push(
                                      '/materials/${material.id}/flashcards',
                                    ),
                                    primary,
                                  ),
                                  _actionButton(
                                    context,
                                    Icons.quiz_outlined,
                                    'Kuis',
                                    isDone,
                                    () => context.push(
                                      '/materials/${material.id}/quiz',
                                    ),
                                    primary,
                                  ),
                                  _actionButton(
                                    context,
                                    Icons.chat_bubble_outline_rounded,
                                    'AI Tutor',
                                    isDone,
                                    () => context.push(
                                      '/materials/${material.id}/chat',
                                    ),
                                    primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Materi tidak tersedia. Periksa koneksi.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(materialsListProvider),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.menu_book_rounded, size: 36, color: primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum ada materi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload materi pertama untuk mulai belajar dengan AI Tutor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    const colors = {
      'uploaded': (Color(0xFFEEF2FF), Color(0xFF4F46E5), 'Diunggah'),
      'done': (Color(0xFFD1FAE5), Color(0xFF047857), 'Selesai'),
      'processing': (Color(0xFFFEF3C7), Color(0xFFB45309), 'Diproses'),
      'failed': (Color(0xFFFEE2E2), Color(0xFFB91C1C), 'Gagal'),
    };
    final value =
        colors[status] ??
        (const Color(0xFFF3F4F6), const Color(0xFF6B7280), 'Unknown');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: value.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.$3,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: value.$2,
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
    Color primary,
  ) {
    return Material(
      color: isActive ? Colors.white : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isActive ? onTap : null,
        splashFactory: MediaQuery.disableAnimationsOf(context)
            ? NoSplash.splashFactory
            : InkRipple.splashFactory,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFFE5E7EB) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? primary : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? primary : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
