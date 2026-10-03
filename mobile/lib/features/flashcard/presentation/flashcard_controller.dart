import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/flashcard_repository.dart';
import '../domain/flashcard_model.dart';
import '../../materials/presentation/courses.dart';

final flashcardReviewCountProvider = FutureProvider<int>((ref) {
  final userId = ref.watch(
    courseUserProvider.select((value) => value.valueOrNull),
  );
  if (userId == null) return 0;
  return ref.watch(flashcardRepositoryProvider).getReviewCount();
});

final flashcardsProvider = FutureProvider.family<List<FlashcardModel>, String>((
  ref,
  materialId,
) async {
  final userId = ref.watch(
    courseUserProvider.select((value) => value.valueOrNull),
  );
  if (userId == null) return [];
  final repo = ref.watch(flashcardRepositoryProvider);
  return repo.getFlashcards(materialId);
});
