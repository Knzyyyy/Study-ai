import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/flashcard_model.dart';

class FlashcardRepository {
  final Dio _dio;

  FlashcardRepository(this._dio);

  // Ambil daftar flashcard
  Future<List<FlashcardModel>> getFlashcards(String materialId) async {
    final response = await _dio.get('/materials/$materialId/flashcards');
    final List data = response.data;
    return data.map((e) => FlashcardModel.fromJson(e)).toList();
  }

  Future<void> markStudied(String materialId, String flashcardId) async {
    await reviewCard(materialId, flashcardId, understood: true);
  }

  Future<void> reviewCard(
    String materialId,
    String flashcardId, {
    required bool understood,
  }) async {
    await _dio.post(
      '/materials/$materialId/flashcards/$flashcardId/studied',
      data: {'understood': understood},
    );
  }

  Future<int> getReviewCount() async {
    final response = await _dio.get('/materials/flashcards/reviews/count');
    final count = response.data['count'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid flashcard review count');
    }
    return count;
  }

  // Minta AI membuat flashcard baru
  Future<void> generateFlashcards(String materialId) async {
    await _dio.post('/materials/$materialId/flashcards/generate');
  }
}

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FlashcardRepository(dio);
});
