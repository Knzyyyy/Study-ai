import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_visuals.dart';
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
      child: CutoutStatCard(
        label: label,
        icon: icon,
        peach:
            icon == Icons.menu_book_outlined ||
            icon == Icons.emoji_events_outlined,
        value: value.when(
          skipLoadingOnRefresh: false,
          data: (text) => Text(
            text,
            style: TextStyle(
              fontSize: text.length > 8 ? 18 : 28,
              fontWeight: FontWeight.w800,
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
        'Flashcard',
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
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final card in cards)
            SizedBox(width: (constraints.maxWidth - 16) / 2, child: card),
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
      color: AppColors.peachSoft,
      borderRadius: BorderRadius.circular(24),
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
    const primary = AppColors.terracotta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.progressSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.progressBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progres latihan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                          color: AppColors.inkSecondary,
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
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 12,
                            backgroundColor: AppColors.peachBorder,
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
    final id = material?.id;
    Widget action(String label, IconData icon, String suffix) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: suffix == 'chat' ? AppColors.charcoal : Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap:
                id == null ||
                    (suffix != 'summary' &&
                        suffix != 'flashcards' &&
                        suffix != 'chat')
                ? null
                : () => context.push('/materials/$id/$suffix'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: id == null
                        ? AppColors.inkMeta
                        : suffix == 'chat'
                        ? AppColors.peach
                        : AppColors.primaryDark,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: id == null
                          ? AppColors.inkMeta
                          : suffix == 'chat'
                          ? Colors.white
                          : AppColors.ink,
                    ),
                  ),
                ],
              ),
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
    final material = latestHomeMaterials(materials).firstOrNull;
    if (material == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pelajari materi terbaru',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  material.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () =>
                      context.go('/materials/${material.id}/summary'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Lanjut belajar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const StudyIllustration(trophy: true, size: 88),
        ],
      ),
    );
  }
}

final selectedCourseProvider = StateProvider<String?>((ref) {
  ref.watch(courseUserProvider);
  return null;
});

final _materialSearchProvider = StateProvider.autoDispose<String>((ref) {
  ref.watch(courseUserProvider);
  return '';
});

final _materialStatusProvider = StateProvider.autoDispose<String?>((ref) {
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
  Widget build(BuildContext context) => const _CanvasMaterialsLibraryScreen();
}

class _CanvasMaterialsLibraryScreen extends ConsumerStatefulWidget {
  const _CanvasMaterialsLibraryScreen();

  @override
  ConsumerState<_CanvasMaterialsLibraryScreen> createState() =>
      _CanvasMaterialsLibraryScreenState();
}

class _CanvasMaterialsLibraryScreenState
    extends ConsumerState<_CanvasMaterialsLibraryScreen> {
  String? _selectedCourseId;
  String? _status;
  String _query = '';
  String _sort = 'Terbaru';
  bool _hasChosenCourse = false;

  Future<void> _deleteMaterial(MaterialModel material) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus materi: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final materialsAsync = ref.watch(materialsListProvider);
    final courses = coursesAsync.valueOrNull ?? const <Course>[];
    final allMaterials = materialsAsync.valueOrNull ?? const <MaterialModel>[];
    if (!_hasChosenCourse && courses.isNotEmpty) {
      _selectedCourseId = courses.first.id;
      _hasChosenCourse = true;
    }
    final effectiveCourse =
        _hasChosenCourse &&
            courses.any((course) => course.id == _selectedCourseId)
        ? _selectedCourseId
        : null;
    final activeCourse = courses
        .where((course) => course.id == effectiveCourse)
        .firstOrNull;
    final courseMaterials = filterMaterials(allMaterials, effectiveCourse);
    final filtered = courseMaterials.where((material) {
      final matchesSearch = '${material.title} ${activeCourse?.name ?? ''}'
          .toLowerCase()
          .contains(_query.trim().toLowerCase());
      final matchesStatus = _status == null || material.status == _status;
      return matchesSearch && matchesStatus;
    }).toList();
    filtered.sort(
      (a, b) => _sort == 'Terbaru'
          ? b.createdAt.compareTo(a.createdAt)
          : a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: AppColors.peach,
        surfaceTintColor: AppColors.peach,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          ref.invalidate(materialsListProvider);
          await ref.read(materialsListProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          key: const ValueKey('materials-library-scroll-view'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _materialsHeader(context, courses, allMaterials.length),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _courseSelector(coursesAsync, courses),
                      if (_hasChosenCourse) ...[
                        const SizedBox(height: 14),
                        CourseProgressCard(materials: courseMaterials),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Cari course atau materi...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(
                              color: AppColors.borderLine,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(
                              color: AppColors.borderLine,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeCourse?.name ?? 'Semua materi',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${courseMaterials.length} dokumen',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkMeta,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Urutkan:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMeta,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sort,
                              borderRadius: BorderRadius.circular(16),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Terbaru',
                                  child: Text('Terbaru'),
                                ),
                                DropdownMenuItem(
                                  value: 'Nama',
                                  child: Text('Nama'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _sort = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _statusPill('Semua', null),
                            _statusPill('Siap', 'done'),
                            _statusPill('Diproses', 'processing'),
                            _statusPill('Gagal', 'failed'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (coursesAsync.hasError || materialsAsync.hasError)
                        _retryMaterials(),
                      if (coursesAsync.isLoading || materialsAsync.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (!coursesAsync.isLoading &&
                          !materialsAsync.isLoading &&
                          filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              allMaterials.isEmpty
                                  ? 'Belum ada materi. Tambahkan course dan unggah materi.'
                                  : 'Tidak ada materi yang cocok dengan filter ini.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                      for (var index = 0; index < filtered.length; index++)
                        _materialCanvasCard(
                          filtered[index],
                          index,
                          activeCourse?.name,
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.go(
                            '/materials/upload/${Uri.encodeComponent(effectiveCourse ?? 'course-123')}',
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tambah materi'),
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
    );
  }

  Widget _materialsHeader(
    BuildContext context,
    List<Course> courses,
    int count,
  ) => Container(
    color: AppColors.peach,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 14,
      20,
      42,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: Colors.white.withValues(alpha: .22),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Kembali ke beranda',
                onPressed: () => context.go('/'),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            const Spacer(),
            Flexible(
              child: FilledButton.icon(
                onPressed: () => showAddCourseDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Tambah course',
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course &',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    'Materi',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Semua bahan kuliahmu, lebih terorganisir.',
                    style: TextStyle(fontSize: 13, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const StudyIllustration(size: 96),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _summaryPill(
              Icons.folder_outlined,
              '${courses.length} Course',
              dark: true,
            ),
            _summaryPill(Icons.description_outlined, '$count Materi'),
          ],
        ),
      ],
    ),
  );

  Widget _summaryPill(IconData icon, String text, {bool dark = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: dark ? AppColors.charcoal : const Color(0xFFFFB986),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dark ? AppColors.charcoal : const Color(0xFFE9915F),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: dark ? Colors.white : AppColors.charcoal,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AppColors.charcoal,
              ),
            ),
          ],
        ),
      );

  Widget _courseSelector(
    AsyncValue<List<Course>> coursesAsync,
    List<Course> courses,
  ) {
    if (coursesAsync.hasError) return _retryMaterials();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final course in courses)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _coursePill(course),
            ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => setState(() {
                _selectedCourseId = null;
                _hasChosenCourse = true;
              }),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: const Text(
                  'Semua course',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coursePill(Course course) {
    final selected = _selectedCourseId == course.id;
    final count =
        (ref.watch(materialsListProvider).valueOrNull ??
                const <MaterialModel>[])
            .where((material) => material.courseId == course.id)
            .length;
    return Material(
      color: selected ? AppColors.charcoal : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => setState(() {
          _selectedCourseId = course.id;
          _hasChosenCourse = true;
        }),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.charcoal : AppColors.borderLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.storage_rounded : Icons.memory_rounded,
                size: 18,
                color: selected ? AppColors.peach : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                course.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? Colors.white24 : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : AppColors.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, String? value) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => setState(() => _status = value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderLine,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _materialCanvasCard(
    MaterialModel material,
    int index,
    String? courseName,
  ) {
    final dark = index.isEven;
    final foreground = dark ? Colors.white : AppColors.charcoal;
    final statusLabel = switch (material.status) {
      'done' => 'Siap',
      'processing' || 'uploaded' => 'Diproses',
      'failed' => 'Gagal',
      _ => 'Status tidak diketahui',
    };
    final statusColor = switch (material.status) {
      'done' => const Color(0xFF145C4D),
      'processing' || 'uploaded' => const Color(0xFFFFDCC8),
      'failed' => const Color(0xFFFFE0DF),
      _ => AppColors.surfaceSubtle,
    };
    final date =
        '${material.createdAt.day}/${material.createdAt.month}/${material.createdAt.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? AppColors.charcoal : AppColors.lavenderCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  material.fileType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (courseName ?? 'MATERI').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: dark ? AppColors.peach : AppColors.charcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (material.status == 'done')
                      const Icon(
                        Icons.check_circle_outline,
                        size: 13,
                        color: Color(0xFF80E0B6),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: material.status == 'done'
                            ? const Color(0xFF80E0B6)
                            : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Hapus materi ${material.title}',
                onPressed: () => _deleteMaterial(material),
                icon: Icon(Icons.more_horiz_rounded, color: foreground),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            material.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${material.pageCount == null ? '' : '${material.pageCount} halaman • '}$date',
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white70 : AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (material.status == 'done') ...[
                _cardAction(Icons.style_outlined, 'Flashcard', foreground),
                _cardAction(
                  Icons.article_outlined,
                  'Ringkasan & Kuis',
                  foreground,
                ),
              ],
              IconButton.filled(
                tooltip: 'Buka materi ${material.title}',
                onPressed: material.status == 'done'
                    ? () => context.push('/materials/${material.id}/summary')
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.charcoal,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardAction(IconData icon, String text, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ],
    ),
  );

  Widget _retryMaterials() => TextButton.icon(
    onPressed: () {
      ref.invalidate(coursesProvider);
      ref.invalidate(materialsListProvider);
    },
    icon: const Icon(Icons.refresh_rounded),
    label: const Text('Gagal memuat. Coba lagi'),
  );
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
    const primary = AppColors.primaryDark;
    final search = materialsOnly ? ref.watch(_materialSearchProvider) : '';
    final status = materialsOnly ? ref.watch(_materialStatusProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: materialsOnly ? AppColors.peach : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 18,
        title: Row(
          children: [
            if (!materialsOnly)
              Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            if (!materialsOnly) const SizedBox(width: 8),
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
        actions: materialsOnly
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: FilledButton.icon(
                    onPressed: () => showAddCourseDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah course'),
                  ),
                ),
              ]
            : null,
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
            padding: EdgeInsets.only(top: materialsOnly ? 0 : 18, bottom: 110),
            child: Column(
              children: [
                if (!materialsOnly) ...[
                  const SizedBox.shrink(),
                ] else ...[
                  Container(
                    width: double.infinity,
                    color: AppColors.peach,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Course &\nMateri',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            StudyIllustration(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              backgroundColor: AppColors.charcoal,
                              label: Text(
                                '${ref.watch(coursesProvider).valueOrNull?.length ?? "—"} Course',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Chip(
                              backgroundColor: AppColors.peachSoft,
                              label: Text(
                                '${materialsAsync.valueOrNull?.length ?? "—"} Materi',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: const SizedBox(height: 24),
                  ),
                ],
                if (!materialsOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Semantics(
                      container: true,
                      label: 'Salam untuk $name. Siap belajar apa hari?',
                      child: Row(
                        children: [
                          Tooltip(
                            message: 'Buka profil',
                            child: Semantics(
                              button: true,
                              label: 'Buka profil',
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => context.go('/profile'),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.lavenderCard,
                                  child: Text(
                                    name.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Siap belajar hari ini?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        _ContinueLearning(
                          materials: materialsAsync.valueOrNull ?? const [],
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
                        _HomeProgressCard(
                          materials: materialsAsync.valueOrNull,
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
                      if (materialsOnly && materialsAsync.hasValue)
                        Text(
                          '${materialsAsync.valueOrNull!.length} materi di perpustakaan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      if (!materialsOnly) const SizedBox(height: 12),
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
                      if (materialsOnly) const SizedBox(height: 10),
                      if (materialsOnly) ...[
                        TextField(
                          onChanged: (value) =>
                              ref.read(_materialSearchProvider.notifier).state =
                                  value.trim().toLowerCase(),
                          decoration: InputDecoration(
                            hintText: 'Cari materi...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: AppColors.borderLine,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: AppColors.borderLine,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in const <String?, String>{
                              null: 'Semua status',
                              'done': 'Siap',
                              'processing': 'Diproses',
                              'failed': 'Gagal',
                            }.entries)
                              ChoiceChip(
                                label: Text(entry.value),
                                selected: status == entry.key,
                                onSelected: (_) =>
                                    ref
                                        .read(_materialStatusProvider.notifier)
                                        .state = entry
                                        .key,
                              ),
                          ],
                        ),
                      ],
                      if (materialsOnly &&
                          ref.watch(selectedCourseProvider) != null &&
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
                      if (materialsOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: FilledButton.icon(
                            onPressed: () => showAddCourseDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah course'),
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
                              .where(
                                (item) =>
                                    item.title.toLowerCase().contains(search) &&
                                    (status == null ||
                                        item.status == status ||
                                        (status == 'processing' &&
                                            item.status == 'uploaded')),
                              )
                              .toList()
                        : latestHomeMaterials(filtered);
                    if (materials.isEmpty) {
                      if (materialsOnly &&
                          (search.isNotEmpty || status != null)) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Tidak ada materi yang cocok. Coba kata kunci atau status lain.',
                          ),
                        );
                      }
                      return _emptyState(context, primary);
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      itemCount: materials.length,
                      itemBuilder: (context, index) {
                        final material = materials[index];
                        final isDone = material.status == 'done';
                        final dark = materialsOnly && index.isEven;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: materialsOnly
                                ? (dark
                                      ? AppColors.charcoal
                                      : AppColors.lavenderCard)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
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
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: dark
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (MediaQuery.sizeOf(context).width > 360)
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: dark
                                      ? Colors.white70
                                      : AppColors.inkSecondary,
                                ),
                              ),
                              if (materialsOnly)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton.filled(
                                    tooltip: 'Buka ringkasan ${material.title}',
                                    onPressed: isDone
                                        ? () => context.push(
                                            '/materials/${material.id}/summary',
                                          )
                                        : null,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.charcoal,
                                      side: const BorderSide(
                                        color: AppColors.charcoal,
                                        width: 2,
                                      ),
                                      minimumSize: const Size(48, 48),
                                    ),
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                ),
                              if (!materialsOnly) const SizedBox(height: 18),
                              if (!materialsOnly)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderLine),
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
                            color: AppColors.inkSecondary,
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
                              backgroundColor: AppColors.charcoal,
                              minimumSize: const Size.fromHeight(48),
                              shape: const StadiumBorder(),
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
    const primary = AppColors.charcoal;
    final color = selected ? Colors.white : AppColors.ink;
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
              color: selected ? primary : AppColors.borderLine,
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
                color: AppColors.lavenderSoft,
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
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload materi pertama untuk mulai belajar dengan AI Tutor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppColors.inkSecondary,
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
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
