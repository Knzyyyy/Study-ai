import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/presentation/home_screen.dart';
import 'quiz_controller.dart';
import '../../materials/presentation/courses.dart';

final quizCourseProvider = StateProvider<String?>((ref) {
  ref.watch(courseUserProvider);
  return null;
});

class QuizHubScreen extends ConsumerWidget {
  const QuizHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsListProvider);
    final progress = ref.watch(quizProgressProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'Kuis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          ref
              .watch(coursesProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () => ref.invalidate(coursesProvider),
                  child: const Text('Gagal memuat mata kuliah. Coba lagi'),
                ),
                data: (courses) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: ref.watch(quizCourseProvider) == null,
                        onSelected: (_) =>
                            ref.read(quizCourseProvider.notifier).state = null,
                      ),
                      for (final course in courses)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(course.name),
                            selected:
                                ref.watch(quizCourseProvider) == course.id,
                            onSelected: (_) =>
                                ref.read(quizCourseProvider.notifier).state =
                                    course.id,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          Expanded(
            child: materials.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
              error: (error, _) =>
                  Center(child: Text('Gagal memuat materi: $error')),
              data: (allItems) {
                final selected = ref.watch(quizCourseProvider);
                final items = filterMaterials(allItems, selected);
                return items.isEmpty
                    ? const Center(
                        child: Text('Belum ada materi untuk dibuat kuis.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final material = items[index];
                          final enabled = material.status == 'done';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFEEF2FF),
                                child: Icon(
                                  Icons.quiz_outlined,
                                  color: enabled
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey,
                                ),
                              ),
                              title: Text(
                                material.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${enabled ? "Siap dikerjakan" : "Materi sedang diproses"}\n'
                                '${progress.valueOrNull?[material.id]?.summary ?? (progress.hasError ? "Gagal memuat progres" : "Memuat progres...")}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: enabled
                                  ? () async {
                                      await context.push(
                                        '/materials/${material.id}/quiz',
                                      );
                                      if (!context.mounted) return;
                                      ref.read(quizProgressProvider.future);
                                    }
                                  : null,
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
