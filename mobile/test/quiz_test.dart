import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_screen.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_review_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:tugas_akhir_mobpro/features/quiz/data/quiz_repository.dart';
import 'package:tugas_akhir_mobpro/features/quiz/domain/quiz_model.dart';
import 'package:tugas_akhir_mobpro/features/quiz/presentation/quiz_controller.dart';

class FakeQuizRepository extends QuizRepository {
  FakeQuizRepository() : super(Dio());
  int? amountRequested;
  String? existingId;
  Completer<String?>? pending;

  @override
  Future<String?> findQuiz(String materialId) async =>
      pending == null ? existingId : await pending!.future;
  @override
  Future<String> generateQuiz(
    String materialId, {
    int amount = 10,
    String difficulty = 'sedang',
  }) async {
    amountRequested = amount;
    return 'quiz';
  }

  @override
  Future<QuizDataModel> getQuiz(String quizId) async => QuizDataModel(
    quizId: quizId,
    title: 'Quiz',
    questions: [
      QuizQuestionModel(id: 'q', question: 'Q', options: ['A', 'B']),
    ],
  );
  @override
  Future<Map<String, dynamic>> submitAnswers(
    String quizId,
    List<Map<String, dynamic>> answers,
  ) async => {'attempt_id': 'a', 'score': 100};
}

void main() {
  test(
    'progress preserves null dates and distinguishes unpracticed from zero',
    () {
      final empty = QuizProgressModel.fromJson({'count': 0});
      expect(empty.summary, 'Belum latihan');
      final practiced = QuizProgressModel.fromJson({
        'count': 1,
        'mean_score': 0,
        'best_score': 0,
        'latest_score': null,
        'last_practiced_at': null,
      });
      expect(practiced.lastPracticedAt, isNull);
      expect(practiced.latestScore, isNull);
      expect(practiced.summary, contains('Indikator pemahaman'));
      expect(practiced.summary, contains('0.0%'));
      expect(practiced.summary, contains('Tidak diketahui'));
      expect(practiced.summary, isNot(contains('Belum latihan')));
    },
  );

  test(
    'successful submission refreshes once, duplicate submission does not',
    () async {
      var refreshes = 0;
      final controller = QuizController(
        FakeQuizRepository(),
        onSubmitted: () => refreshes++,
      );
      await controller.startQuiz('m');
      controller.selectAnswer('q', 0);
      await controller.submitQuiz();
      await controller.submitQuiz();
      expect(refreshes, 1);
      controller.dispose();
    },
  );

  testWidgets('detail shows unpracticed progress without mastery claim', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
          quizProgressProvider.overrideWith(
            (ref) async => {
              'm': QuizProgressModel.fromJson({'count': 0}),
            },
          ),
          quizHistoryProvider('m').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: QuizScreen(materialId: 'm')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum latihan'), findsOneWidget);
    expect(find.textContaining('0.0%'), findsNothing);
  });

  test('start reuses persisted quiz and generates only when absent', () async {
    final repository = FakeQuizRepository()..existingId = 'persisted';
    final controller = QuizController(repository);
    await controller.startQuiz('material');
    expect(controller.state.activeQuiz?.quizId, 'persisted');
    expect(repository.amountRequested, isNull);
    repository.existingId = null;
    await controller.startQuiz('material');
    expect(repository.amountRequested, 10);
    controller.dispose();
  });

  test('reset ignores pending load', () async {
    final repository = FakeQuizRepository()..pending = Completer<String?>();
    final controller = QuizController(repository);
    final loading = controller.startQuiz('material');
    controller.reset();
    repository.pending!.complete('old');
    await loading;
    expect(controller.state.activeQuiz, isNull);
    expect(controller.state.isLoading, isFalse);
    controller.dispose();
  });

  test('material providers isolate answers and result', () async {
    final container = ProviderContainer(
      overrides: [
        quizRepositoryProvider.overrideWithValue(FakeQuizRepository()),
      ],
    );
    final first = container.listen(quizControllerProvider('first'), (_, _) {});
    final second = container.listen(
      quizControllerProvider('second'),
      (_, _) {},
    );
    final controller = container.read(quizControllerProvider('first').notifier);
    await controller.startQuiz('first');
    controller.selectAnswer('q', 0);
    await controller.submitQuiz();
    expect(container.read(quizControllerProvider('second')).activeQuiz, isNull);
    expect(
      container.read(quizControllerProvider('second')).selectedAnswers,
      isEmpty,
    );
    expect(
      container.read(quizControllerProvider('second')).finalResult,
      isNull,
    );
    first.close();
    second.close();
    container.dispose();
  });
  test('review parses chosen, correct, explanation and date', () {
    final review = QuizReviewModel.fromJson({
      'attempt': {
        'id': 'a',
        'title': 'Quiz',
        'score': 50,
        'created_at': '2026-01-01T00:00:00Z',
      },
      'questions': [
        {
          'id': 'q',
          'question': 'Q',
          'options': ['A', 'B'],
          'selected_index': 0,
          'correct_index': 1,
          'explanation': 'Because',
        },
      ],
    });
    expect(review.questions.single.chosenOption, 'A');
    expect(review.questions.single.correctIndex, 1);
    expect(review.questions.single.explanation, 'Because');
    expect(review.attempt.score, 50);
    expect(review.attempt.createdAt!.toUtc().year, 2026);
  });
  test('new quiz requests ten and clears previous result', () async {
    final repository = FakeQuizRepository();
    final controller = QuizController(repository);
    await controller.startNewQuiz('material');
    expect(repository.amountRequested, 10);
    controller.selectAnswer('q', 0);
    await controller.submitQuiz();
    expect(controller.state.finalResult?['attempt_id'], 'a');
    await controller.startNewQuiz('material');
    expect(controller.state.finalResult, isNull);
    expect(controller.state.selectedAnswers, isEmpty);
    controller.selectAnswer('unknown', 0);
    controller.selectAnswer('q', 9);
    expect(controller.state.selectedAnswers, isEmpty);
    controller.dispose();
  });
}
