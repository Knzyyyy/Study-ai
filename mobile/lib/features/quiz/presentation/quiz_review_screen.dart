import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/quiz_repository.dart';
import '../domain/quiz_model.dart';

final quizHistoryProvider = FutureProvider.autoDispose
    .family<List<QuizAttemptModel>, String>((ref, materialId) {
      return ref.watch(quizRepositoryProvider).getAttempts(materialId);
    });

final quizReviewProvider = FutureProvider.autoDispose
    .family<QuizReviewModel, String>((ref, attemptId) {
      return ref.watch(quizRepositoryProvider).getReview(attemptId);
    });

class QuizHistory extends ConsumerWidget {
  final String materialId;
  const QuizHistory({super.key, required this.materialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(quizHistoryProvider(materialId))
        .when(
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Column(
            children: [
              Text('Gagal memuat riwayat: $error'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(quizHistoryProvider(materialId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
          data: (attempts) => Column(
            children: [
              const Text(
                'Riwayat Kuis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (attempts.isEmpty) const Text('Belum ada kuis selesai.'),
              for (final attempt in attempts)
                ListTile(
                  title: Text(attempt.title),
                  subtitle: Text(
                    'Skor ${attempt.score} • ${attempt.createdAt ?? 'Tanggal tidak tersedia'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizReviewScreen(attemptId: attempt.id),
                    ),
                  ),
                ),
            ],
          ),
        );
  }
}

class QuizReviewScreen extends ConsumerWidget {
  final String attemptId;
  const QuizReviewScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembahasan Kuis')),
      body: ref
          .watch(quizReviewProvider(attemptId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Gagal memuat pembahasan: $error'),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(quizReviewProvider(attemptId)),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            data: (review) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${review.attempt.title}\nSkor ${review.attempt.score} • ${review.attempt.createdAt ?? 'Tanggal tidak tersedia'}',
                ),
                for (final item in review.questions)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.question.question,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (var i = 0; i < item.question.options.length; i++)
                            Text(
                              '${i + 1}. ${item.question.options[i]}${i == item.selectedIndex ? " (Pilihanmu)" : ""}${i == item.correctIndex ? " (Benar)" : ""}',
                            ),
                          const SizedBox(height: 8),
                          Text('Jawabanmu: ${item.chosenOption}'),
                          Text(
                            'Jawaban benar: ${item.question.options[item.correctIndex]}',
                          ),
                          Text(item.explanation),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
