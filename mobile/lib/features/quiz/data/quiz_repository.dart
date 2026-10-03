import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/quiz_model.dart';

class QuizRepository {
  final Dio _dio;

  QuizRepository(this._dio);

  // 1. Generate Kuis Baru
  Future<String> generateQuiz(
    String materialId, {
    int amount = 10,
    String difficulty = "sedang",
  }) async {
    final response = await _dio.post(
      '/materials/$materialId/quiz/generate',
      data: {"amount": amount, "difficulty": difficulty},
    );
    return response.data['quiz_id'];
  }

  Future<String?> findQuiz(String materialId) async {
    final response = await _dio.get('/materials/$materialId/quiz');
    return response.data['quiz']?['id'] as String?;
  }

  // 2. Ambil Soal Kuis (Tanpa kunci jawaban)
  Future<QuizDataModel> getQuiz(String quizId) async {
    final response = await _dio.get('/quizzes/$quizId');
    final data = response.data;

    final questions = (data['questions'] as List)
        .map((q) => QuizQuestionModel.fromJson(q))
        .toList();

    return QuizDataModel(
      quizId: data['quiz']['id'],
      title: data['quiz']['title'],
      questions: questions,
    );
  }

  Future<Map<String, QuizProgressModel>> getProgress() async {
    final response = await _dio.get('/quiz-progress');
    return (response.data['progress'] as Map<String, dynamic>).map(
      (id, value) => MapEntry(id, QuizProgressModel.fromJson(value)),
    );
  }

  Future<List<QuizAttemptModel>> getAttempts(String materialId) async {
    final response = await _dio.get('/materials/$materialId/quiz/attempts');
    return (response.data['attempts'] as List)
        .map((item) => QuizAttemptModel.fromJson(item))
        .toList();
  }

  Future<QuizReviewModel> getReview(String attemptId) async {
    final response = await _dio.get('/quiz-attempts/$attemptId');
    return QuizReviewModel.fromJson(response.data);
  }

  // 3. Submit Jawaban dan Dapatkan Skor
  Future<Map<String, dynamic>> submitAnswers(
    String quizId,
    List<Map<String, dynamic>> answers,
  ) async {
    final response = await _dio.post(
      '/quizzes/$quizId/attempts',
      data: {"answers": answers},
    );
    return response.data; // Mengembalikan data {score, benar, total, dll}
  }
}

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return QuizRepository(dio);
});
