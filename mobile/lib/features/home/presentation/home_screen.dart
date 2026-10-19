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
        'Materi dilatih',
        Icons.track_changes_rounded,
        quizzes.whenData((items) {
          final practiced =
              materials.valueOrNull
                  ?.where((item) => (items[item.id]?.count ?? 0) > 0)
                  .length ??
              0;
          return practiced == 0 ? '0' : '$practiced';
        }),
        () => ref.invalidate(quizProgressProvider),
      ),
      metric(
        'Rata-rata skor kuis',
        Icons.emoji_events_outlined,
        quizzes.whenData((items) {
          final score = weightedQuizScore(items.values);
          return score == null
              ? 'Belum ada skor'
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
            SizedBox(width: (constraints.maxWidth - 10) / 2, child: card),
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

class _HomeProgressCard extends ConsumerWidget {
  const _HomeProgressCard({required this.materials});

  final List<MaterialModel>? materials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primary = Color(0xFF7560B5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progres latihan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (materials == null)
            const LinearProgressIndicator(minHeight: 6)
          else
            ref
                .watch(quizProgressProvider)
                .when(
                  data: (progress) {
                    final items = materials!;
                    if (items.isEmpty) {
                      return const Text(
                        'Belum latihan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF716B80),
                        ),
                      );
                    }
                    final practiced = items
                        .where((item) => (progress[item.id]?.count ?? 0) > 0)
                        .length;
                    final value = practiced / items.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$practiced/${items.length} materi dilatih',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF716B80),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF2EDF9),
                            color: primary,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 6),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(quizProgressProvider),
                    child: const Text('Gagal memuat progres. Coba lagi'),
                  ),
                ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.material});

  final MaterialModel? material;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7560B5);
    final id = material?.id;
    Widget action(String label, IconData icon, String suffix) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton.icon(
          onPressed: id == null
              ? null
              : () => context.push('/materials/$id/$suffix'),
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE7E2F0)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        action('Ringkasan', Icons.article_outlined, 'summary'),
        action('Flashcard', Icons.style_outlined, 'flashcards'),
        action('Tanya Tutor', Icons.chat_bubble_outline_rounded, 'chat'),
      ],
    );
  }
}

class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning({required this.materials});

  final List<MaterialModel> materials;

  @override
  Widget build(BuildContext context) {
    final primary = Color(0xFF7560B5);
    final material = latestHomeMaterials(materials).firstOrNull;
    if (material == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E2F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2EDF9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.article_rounded, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pelajari materi terbaru',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  material.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF716B80),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Lanjut belajar',
            onPressed: () => context.go('/materials/${material.id}/summary'),
            icon: Icon(Icons.arrow_forward_rounded, color: primary),
          ),
        ],
      ),
    );
  }
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
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                materialsOnly ? 'Materi' : 'AI Tutor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
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
              top: materialsOnly ? 20 : 18,
              bottom: materialsOnly ? 150 : 150,
            ),
            child: Column(
              children: [
                if (!materialsOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Semantics(
                      container: true,
                      label: 'Salam untuk $name. Siap belajar apa hari?',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7E2F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo, $name',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF30283F),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Siap belajar apa hari?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF716B80),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ExcludeSemantics(
                              child: Tooltip(
                                message: 'Buka profil',
                                child: GestureDetector(
                                  onTap: () => context.go('/profile'),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAE3F7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFD8CCEC),
                                      ),
                                    ),
                                    child: Text(
                                      name.characters.first.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!materialsOnly) ...[
                        const Text(
                          'Ringkasan belajar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const HomeStatistics(),
                        const SizedBox(height: 18),
                        _HomeProgressCard(
                          materials: materialsAsync.valueOrNull,
                        ),
                        const SizedBox(height: 18),
                        _QuickActions(
                          material: latestHomeMaterials(
                            (materialsAsync.valueOrNull ??
                                    const <MaterialModel>[])
                                .where((item) => item.status == 'done')
                                .toList(),
                          ).firstOrNull,
                        ),
                        const SizedBox(height: 18),
                        _ContinueLearning(
                          materials: materialsAsync.valueOrNull ?? const [],
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        materialsOnly ? 'Semua materi' : 'Materi terbaru',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (materialsAsync.hasValue)
                        Text(
                          '${materialsAsync.valueOrNull!.length} materi di perpustakaan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF716B80),
                          ),
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
                                  _courseChip(
                                    context,
                                    label: 'Semua',
                                    selected:
                                        ref.watch(selectedCourseProvider) ==
                                        null,
                                    onTap: () =>
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
                                      child: _courseChip(
                                        context,
                                        label: course.name,
                                        selected:
                                            ref.watch(selectedCourseProvider) ==
                                            course.id,
                                        onTap: () =>
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
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => showAddCourseDialog(context, ref),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Tambah Mata Kuliah'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7560B5),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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
                                    tooltip: 'Hapus materi ${material.title}',
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  const SizedBox(height: 8),
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
                                  const SizedBox(height: 8),
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
                                  const SizedBox(height: 8),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE7E2F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tambahkan materi baru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PDF atau PPTX • Maks. 20 MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF716B80),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.go(
                              '/materials/upload/${Uri.encodeComponent(ref.read(selectedCourseProvider) ?? 'course-123')}',
                            ),
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 18,
                            ),
                            label: const Text('Tambah materi'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7560B5),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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

  Widget _courseChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const primary = Color(0xFF7560B5);
    final color = selected ? Colors.white : const Color(0xFF30283F);
    return Material(
      color: selected ? primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primary : const Color(0xFFE7E2F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
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
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isActive ? onTap : null,
        icon: Icon(
          icon,
          size: 18,
          color: isActive ? primary : const Color(0xFF9CA3AF),
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? primary : const Color(0xFF9CA3AF),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: isActive ? Colors.white : const Color(0xFFF3F4F6),
          side: BorderSide(
            color: isActive ? const Color(0xFFE5E7EB) : Colors.transparent,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
