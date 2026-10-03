import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quiz_controller.dart';
import 'quiz_review_screen.dart';

class QuizScreen extends ConsumerWidget {
  final String materialId;

  const QuizScreen({super.key, required this.materialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(quizProgressProvider);
    final progressText =
        progress.valueOrNull?[materialId]?.summary ??
        (progress.hasError ? 'Gagal memuat progres' : 'Memuat progres...');
    final quizState = ref.watch(quizControllerProvider(materialId));
    final quizController = ref.read(
      quizControllerProvider(materialId).notifier,
    );

    // 1. Tampilan Saat Loading (Generate / Submit)
    if (quizState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kuis AI')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Menyiapkan / Memproses Kuis...'),
            ],
          ),
        ),
      );
    }

    // 2. Tampilan Saat Kuis Selesai (Menampilkan Skor Akhir)
    if (quizState.finalResult != null) {
      final skor = quizState.finalResult!['score'];
      final benar = quizState.finalResult!['benar'];
      final total = quizState.finalResult!['total'];

      return Scaffold(
        appBar: AppBar(title: const Text('Hasil Kuis')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  skor >= 70
                      ? Icons.emoji_events
                      : Icons.sentiment_dissatisfied,
                  size: 100,
                  color: skor >= 70 ? Colors.amber : Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  'Skor Kamu: $skor',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Menjawab Benar $benar dari $total Soal',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(progressText),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizReviewScreen(
                        attemptId:
                            quizState.finalResult!['attempt_id'] as String,
                      ),
                    ),
                  ),
                  child: const Text('Lihat Pembahasan'),
                ),
                ElevatedButton(
                  onPressed: () {
                    quizController.reset();
                    Navigator.of(context).pop(); // Kembali ke halaman materi
                  },
                  child: const Text('Tutup Kuis'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Tampilan Awal (Belum mulai kuis)
    if (quizState.activeQuiz == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kuis Latihan')),
        body: Center(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.quiz_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Uji pemahamanmu dari materi ini!',
                style: TextStyle(fontSize: 18),
              ),
              if (quizState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    quizState.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => quizController.startQuiz(materialId),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Mulai Kuis'),
              ),
              TextButton(
                onPressed: () => quizController.startNewQuiz(materialId),
                child: const Text('Buat Kuis Baru (10 Soal)'),
              ),
              const SizedBox(height: 24),
              Text(progressText),
              if (progress.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(quizProgressProvider),
                  child: const Text('Coba lagi'),
                ),
              QuizHistory(materialId: materialId),
            ],
          ),
        ),
      );
    }

    // 4. Tampilan Sedang Mengerjakan Kuis
    final quiz = quizState.activeQuiz!;
    final questions = quiz.questions;

    // Mengecek apakah semua soal sudah dijawab (untuk mengaktifkan tombol Submit)
    final isAllAnswered = quizState.selectedAnswers.length == questions.length;

    return Scaffold(
      appBar: AppBar(title: Text(quiz.title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length + 1, // +1 untuk tombol Submit di bawah
        itemBuilder: (context, index) {
          if (index == questions.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ElevatedButton(
                onPressed: isAllAnswered
                    ? () => quizController.submitQuiz()
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isAllAnswered ? Colors.green : Colors.grey,
                ),
                child: Text(
                  quizState.errorMessage == null
                      ? 'Kumpulkan Kuis'
                      : '${quizState.errorMessage}\nCoba kirim lagi',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            );
          }

          final q = questions[index];
          final selectedOption = quizState.selectedAnswers[q.id];

          return Card(
            margin: const EdgeInsets.only(bottom: 24),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${q.question}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Render 4 opsi jawaban
                  ...List.generate(q.options.length, (optIndex) {
                    return RadioListTile<int>(
                      title: Text(
                        q.options[optIndex],
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: optIndex,
                      groupValue: selectedOption,
                      onChanged: (value) {
                        if (value != null) {
                          quizController.selectAnswer(q.id, value);
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blue,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
