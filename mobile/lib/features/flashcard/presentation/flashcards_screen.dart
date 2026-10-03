import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flashcard_controller.dart';
import '../data/flashcard_repository.dart';

class FlashcardsScreen extends ConsumerStatefulWidget {
  final String materialId;

  const FlashcardsScreen({super.key, required this.materialId});

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen> {
  int currentIndex = 0;
  bool showBack = false;
  bool saving = false;

  Future<void> markStudied(String cardId) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref
          .read(flashcardRepositoryProvider)
          .markStudied(widget.materialId, cardId);
      if (!mounted) return;
      ref.invalidate(flashcardsProvider(widget.materialId));
      ref.invalidate(flashcardReviewCountProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flashcardsAsync = ref.watch(flashcardsProvider(widget.materialId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards Belajar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generate Flashcard dengan AI',
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI sedang membuat flashcard...'),
                  ),
                );
                await ref
                    .read(flashcardRepositoryProvider)
                    .generateFlashcards(widget.materialId);
                ref.invalidate(flashcardsProvider(widget.materialId));
                setState(() {
                  currentIndex = 0;
                  showBack = false;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Flashcard berhasil dibuat! 🎉'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Gagal generate: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: flashcardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Belum ada flashcard untuk materi ini.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(flashcardRepositoryProvider)
                            .generateFlashcards(widget.materialId);
                        ref.invalidate(flashcardsProvider(widget.materialId));
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Buat Flashcard Sekarang'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Batasi index agar tidak out of range
          if (currentIndex >= cards.length) currentIndex = cards.length - 1;
          final currentCard = cards[currentIndex];

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Kartu ${currentIndex + 1} dari ${cards.length}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Kartu Interaktif (Tap untuk membalik)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showBack = !showBack;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: showBack
                          ? Colors.indigo.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: showBack
                            ? Colors.indigo.shade200
                            : Colors.blue.shade200,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              showBack
                                  ? 'JAWABAN / DEFINISI'
                                  : 'PERTANYAAN / ISTILAH',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: showBack ? Colors.indigo : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              showBack ? currentCard.back : currentCard.front,
                              style: const TextStyle(fontSize: 18, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '(Ketuk kartu untuk membalik)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving || currentCard.studied
                      ? null
                      : () => markStudied(currentCard.id),
                  icon: Icon(
                    currentCard.studied ? Icons.check_circle : Icons.check,
                  ),
                  label: Text(
                    saving
                        ? 'Menyimpan...'
                        : currentCard.studied
                        ? 'Sudah dipelajari'
                        : 'Tandai sudah dipelajari',
                  ),
                ),
                const SizedBox(height: 16),

                // Tombol Navigasi Sebelumnya / Selanjutnya
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: currentIndex > 0
                          ? () {
                              setState(() {
                                currentIndex--;
                                showBack = false;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Sebelumnya'),
                    ),
                    ElevatedButton.icon(
                      onPressed: currentIndex < cards.length - 1
                          ? () {
                              setState(() {
                                currentIndex++;
                                showBack = false;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Selanjutnya'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
