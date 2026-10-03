import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/quiz_repository.dart';
import '../domain/quiz_model.dart';
import '../../materials/presentation/courses.dart';
import 'quiz_review_screen.dart';

final quizProgressProvider = FutureProvider<Map<String, QuizProgressModel>>((
  ref,
) {
  final userId = ref.watch(
    courseUserProvider.select((value) => value.valueOrNull),
  );
  if (userId == null) return {};
  return ref.watch(quizRepositoryProvider).getProgress();
});

class QuizState {
  final bool isLoading;
  final QuizDataModel? activeQuiz;
  final Map<String, int> selectedAnswers; // Map(QuestionId -> Index Pilihan)
  final Map<String, dynamic>? finalResult; // Nilai akhir dari backend
  final String? errorMessage;

  QuizState({
    this.isLoading = false,
    this.activeQuiz,
    this.selectedAnswers = const {},
    this.finalResult,
    this.errorMessage,
  });

  QuizState copyWith({
    bool? isLoading,
    QuizDataModel? activeQuiz,
    Map<String, int>? selectedAnswers,
    Map<String, dynamic>? finalResult,
    String? errorMessage,
  }) {
    return QuizState(
      isLoading: isLoading ?? this.isLoading,
      activeQuiz: activeQuiz ?? this.activeQuiz,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      finalResult: finalResult ?? this.finalResult,
      errorMessage: errorMessage,
    );
  }
}

class QuizController extends StateNotifier<QuizState> {
  final QuizRepository _repository;
  final void Function()? onSubmitted;

  QuizController(this._repository, {this.onSubmitted}) : super(QuizState());

  int _revision = 0;

  Future<void> startQuiz(String materialId, {bool generateNew = false}) async {
    if (state.isLoading) return;
    final revision = ++_revision;
    state = QuizState(isLoading: true);
    try {
      final existingId = generateNew
          ? null
          : await _repository.findQuiz(materialId);
      if (!mounted || revision != _revision) return;
      final quizId = existingId ?? await _repository.generateQuiz(materialId);
      if (!mounted || revision != _revision) return;
      final quizData = await _repository.getQuiz(quizId);
      if (!mounted || revision != _revision) return;
      state = QuizState(activeQuiz: quizData);
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = QuizState(errorMessage: 'Gagal menyiapkan kuis: $e');
    }
  }

  Future<void> startNewQuiz(String materialId) =>
      startQuiz(materialId, generateNew: true);

  // Menyimpan pilihan user secara lokal di HP
  void selectAnswer(String questionId, int optionIndex) {
    if (state.isLoading || state.finalResult != null) return;
    final questions = state.activeQuiz?.questions.where(
      (q) => q.id == questionId,
    );
    if (questions == null ||
        questions.isEmpty ||
        optionIndex < 0 ||
        optionIndex >= questions.first.options.length) {
      return;
    }
    final newAnswers = Map<String, int>.from(state.selectedAnswers);
    newAnswers[questionId] = optionIndex;
    state = state.copyWith(selectedAnswers: newAnswers);
  }

  // Mengumpulkan kuis ke dosen (backend)
  Future<void> submitQuiz() async {
    if (state.activeQuiz == null ||
        state.isLoading ||
        state.finalResult != null) {
      return;
    }

    final revision = _revision;
    state = state.copyWith(isLoading: true, errorMessage: null);

    // Ubah format Map ke format List JSON yang diminta backend
    List<Map<String, dynamic>> answersList = [];
    state.selectedAnswers.forEach((qId, index) {
      answersList.add({"question_id": qId, "selected_index": index});
    });

    try {
      final result = await _repository.submitAnswers(
        state.activeQuiz!.quizId,
        answersList,
      );
      onSubmitted?.call();
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        isLoading: false,
        finalResult: result, // Tampilkan skor akhir
      );
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mengirim kuis: $e',
      );
    }
  }

  void reset() {
    _revision++;
    state = QuizState();
  }
}

// Provider untuk Controller
final quizControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizController, QuizState, String>((ref, materialId) {
      final repo = ref.watch(quizRepositoryProvider);
      return QuizController(
        repo,
        onSubmitted: () {
          ref.invalidate(quizProgressProvider);
          ref.invalidate(quizHistoryProvider(materialId));
        },
      );
    });
