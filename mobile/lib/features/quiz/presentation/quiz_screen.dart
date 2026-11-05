import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/study_visuals.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import '../domain/quiz_model.dart';
import 'quiz_controller.dart';
import 'quiz_result_widgets.dart';
import 'quiz_review_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    required this.materialId,
    this.amount = 10,
    this.difficulty = 'sedang',
    this.generateNew = false,
  });

  final String materialId;
  final int amount;
  final String difficulty;
  final bool generateNew;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const _answerLetters = ['A', 'B', 'C', 'D'];

  int _currentIndex = 0;
  final Set<String> _flaggedQuestionIds = {};
  DateTime? _sessionStartedAt;
  DateTime? _sessionCompletedAt;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant QuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.materialId != widget.materialId) {
      _timer?.cancel();
      _currentIndex = 0;
      _flaggedQuestionIds.clear();
      _sessionStartedAt = null;
      _sessionCompletedAt = null;
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSessionClock() {
    if (_sessionStartedAt != null) return;
    _sessionStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _sessionStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_sessionStartedAt!));
    });
  }

  void _completeSessionClock() {
    _sessionCompletedAt ??= DateTime.now();
    _timer?.cancel();
    if (_sessionStartedAt != null) {
      _elapsed = _sessionCompletedAt!.difference(_sessionStartedAt!);
    }
  }

  String get _durationLabel {
    final totalSeconds = _elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final materialTitle = ref
        .watch(materialsListProvider)
        .valueOrNull
        ?.where((material) => material.id == widget.materialId)
        .firstOrNull
        ?.title;
    final progress = ref.watch(quizProgressProvider);
    final progressText =
        progress.valueOrNull?[widget.materialId]?.summary ??
        (progress.hasError ? 'Gagal memuat progres' : 'Memuat progres...');
    final quizState = ref.watch(quizControllerProvider(widget.materialId));
    final quizController = ref.read(
      quizControllerProvider(widget.materialId).notifier,
    );

    if (quizState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: StudyFeatureAppBar(
          title: 'Kuis AI',
          subtitle: materialTitle,
          onBack: () => context.pop(),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryDark),
              SizedBox(height: 16),
              Text('Menyiapkan / Memproses Kuis...'),
            ],
          ),
        ),
      );
    }

    if (quizState.finalResult != null) {
      _completeSessionClock();
      final result = quizState.finalResult!;
      final score = (result['score'] as num?)?.round() ?? 0;
      final correct = (result['benar'] as num?)?.toInt() ?? 0;
      final total = (result['total'] as num?)?.toInt() ?? 0;
      final attemptId = result['attempt_id']?.toString() ?? '';
      final history = ref.watch(quizHistoryProvider(widget.materialId));
      final previousScore = _previousScore(history.valueOrNull, attemptId);

      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              _ResultHeader(
                title: 'Hasil Kuis',
                subtitle: materialTitle ?? 'Kuis AI',
                onBack: () => context.pop(),
              ),
              const SizedBox(height: 20),
              QuizScoreHero(
                score: score,
                correctCount: correct,
                total: total,
                durationText: _durationLabel,
                difficulty: widget.difficulty,
                previousScore: previousScore,
                comparisonLoading: history.isLoading,
              ),
              const SizedBox(height: 14),
              Text(
                progressText,
                style: const TextStyle(
                  color: AppColors.inkSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: attemptId.isEmpty
                    ? null
                    : () => context.push<void>(
                        '/quiz-attempts/$attemptId/review'
                        '?material_id=${Uri.encodeQueryComponent(widget.materialId)}'
                        '&duration_seconds=${_elapsed.inSeconds}'
                        '&difficulty=${Uri.encodeQueryComponent(widget.difficulty)}',
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.charcoal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.only(left: 22, right: 8),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lihat Pembahasan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    _ActionCircle(icon: Icons.arrow_forward_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  quizController.reset();
                  context.pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.borderLine),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Tutup Kuis'),
              ),
            ],
          ),
        ),
      );
    }

    if (quizState.activeQuiz == null) {
      final materialProgress = progress.valueOrNull?[widget.materialId];
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              Row(
                children: [
                  AppBackButton(
                    tooltip: 'Kembali',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kuis Latihan',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          materialTitle ?? 'Kuis materi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.peach,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${materialProgress?.count ?? 0} Latihan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1816181D),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(26),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'EVALUASI MATERI',
                              style: TextStyle(
                                color: AppColors.charcoal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 28,
                      right: 18,
                      child: Transform.rotate(
                        angle: .1,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: AppColors.lavenderCard,
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            color: AppColors.charcoal,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 49, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 78),
                            child: Text(
                              'Uji pemahamanmu dari materi ini!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Padding(
                            padding: const EdgeInsets.only(right: 74),
                            child: Text(
                              'Latihan AI berdasarkan ${materialTitle ?? 'materi ini'}.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 19),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: () => widget.generateNew
                                  ? quizController.startNewQuiz(
                                      widget.materialId,
                                      amount: widget.amount,
                                      difficulty: widget.difficulty,
                                    )
                                  : quizController.startQuiz(
                                      widget.materialId,
                                      amount: widget.amount,
                                      difficulty: widget.difficulty,
                                    ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.peach,
                                foregroundColor: AppColors.charcoal,
                                padding: const EdgeInsets.only(
                                  left: 18,
                                  right: 8,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.play_arrow_rounded, size: 21),
                                      SizedBox(width: 7),
                                      Text(
                                        'Mulai Kuis Sekarang',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: AppColors.charcoal,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (quizState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Kuis belum siap. Coba lagi.',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!widget.generateNew)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.charcoal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => quizController.startNewQuiz(
                    widget.materialId,
                    amount: widget.amount,
                    difficulty: widget.difficulty,
                  ),
                  child: Text('Buat kuis baru • ${widget.amount} soal'),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Indikator Pemahaman',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (materialProgress?.lastPracticedAt case final date?)
                    Text(
                      'Terakhir: ${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(
                        color: AppColors.inkMeta,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CutoutStatCard(
                      label: 'Rata-rata skor',
                      icon: Icons.pie_chart_outline_rounded,
                      peach: true,
                      value: Text(
                        materialProgress?.meanScore == null
                            ? '—'
                            : '${materialProgress!.meanScore!.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CutoutStatCard(
                      label: 'Skor terbaik',
                      icon: Icons.emoji_events_outlined,
                      value: Text(
                        materialProgress?.bestScore?.toStringAsFixed(1) ?? '—',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _LatestScoreStrip(
                score: materialProgress?.latestScore,
                count: materialProgress?.count ?? 0,
              ),
              if (progress.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(quizProgressProvider),
                  child: const Text('Coba lagi'),
                ),
              const SizedBox(height: 22),
              QuizHistory(materialId: widget.materialId),
            ],
          ),
        ),
      );
    }

    final quiz = quizState.activeQuiz!;
    final questions = quiz.questions;
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: StudyFeatureAppBar(
          title: quiz.title,
          subtitle: materialTitle,
          onBack: () => context.pop(),
        ),
        body: const Center(child: Text('Belum ada soal pada kuis ini.')),
      );
    }

    if (_currentIndex >= questions.length) {
      _currentIndex = questions.length - 1;
    }
    _startSessionClock();
    final question = questions[_currentIndex];
    final selectedOption = quizState.selectedAnswers[question.id];
    final isAllAnswered = quizState.selectedAnswers.length == questions.length;
    final flagged = _flaggedQuestionIds.contains(question.id);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _SessionHeader(
              materialTitle: materialTitle ?? quiz.title,
              duration: _durationLabel,
              onExit: () => context.pop(),
              onOpenGrid: () => _showQuestionGrid(
                context,
                questions: questions,
                answers: quizState.selectedAnswers,
              ),
            ),
            const SizedBox(height: 22),
            _QuestionProgress(
              currentIndex: _currentIndex,
              questions: questions,
              selectedAnswers: quizState.selectedAnswers,
              flaggedIds: _flaggedQuestionIds,
            ),
            const SizedBox(height: 20),
            _QuestionCard(
              index: _currentIndex,
              question: question.question,
              flagged: flagged,
              onToggleFlag: () => setState(() {
                if (flagged) {
                  _flaggedQuestionIds.remove(question.id);
                } else {
                  _flaggedQuestionIds.add(question.id);
                }
              }),
            ),
            const SizedBox(height: 18),
            for (
              var optionIndex = 0;
              optionIndex < question.options.length;
              optionIndex++
            ) ...[
              _AnswerOption(
                letter: optionIndex < _answerLetters.length
                    ? _answerLetters[optionIndex]
                    : String.fromCharCode(65 + optionIndex),
                text: question.options[optionIndex],
                selected: selectedOption == optionIndex,
                onTap: () =>
                    quizController.selectAnswer(question.id, optionIndex),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            if (quizState.errorMessage != null) ...[
              _InlineError(message: quizState.errorMessage!),
              const SizedBox(height: 12),
            ],
            _SessionNavigation(
              canGoPrevious: _currentIndex > 0,
              isLastQuestion: _currentIndex == questions.length - 1,
              canSubmit: isAllAnswered,
              onPrevious: _currentIndex > 0
                  ? () => setState(() => _currentIndex--)
                  : null,
              onNext: _currentIndex < questions.length - 1
                  ? () => setState(() => _currentIndex++)
                  : isAllAnswered
                  ? quizController.submitQuiz
                  : null,
            ),
            if (_currentIndex == questions.length - 1 && !isAllAnswered) ...[
              const SizedBox(height: 9),
              Text(
                'Jawab semua soal sebelum mengumpulkan kuis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSecondary.withValues(alpha: .85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int? _previousScore(
    List<QuizAttemptModel>? attempts,
    String currentAttemptId,
  ) {
    if (attempts == null) return null;
    for (final attempt in attempts) {
      if (attempt.id != currentAttemptId) return attempt.score;
    }
    return null;
  }

  Future<void> _showQuestionGrid(
    BuildContext context, {
    required List<QuizQuestionModel> questions,
    required Map<String, int> answers,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLine,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Daftar Soal',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Pilih nomor untuk berpindah soal.',
              style: TextStyle(color: AppColors.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              itemCount: questions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final question = questions[index];
                final answered = answers.containsKey(question.id);
                final isCurrent = index == _currentIndex;
                final flagged = _flaggedQuestionIds.contains(question.id);
                final background = isCurrent
                    ? AppColors.charcoal
                    : answered
                    ? AppColors.peachSoft
                    : Colors.white;
                final foreground = isCurrent
                    ? Colors.white
                    : AppColors.charcoal;
                return Material(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() => _currentIndex = index);
                      Navigator.pop(sheetContext);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? AppColors.charcoal
                              : answered
                              ? AppColors.peachBorder
                              : AppColors.borderLine,
                          width: 1.3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (flagged)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.flag_rounded,
                                size: 12,
                                color: AppColors.terracotta,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.materialTitle,
    required this.duration,
    required this.onExit,
    required this.onOpenGrid,
  });

  final String materialTitle;
  final String duration;
  final VoidCallback onExit;
  final VoidCallback onOpenGrid;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.borderLine, width: 1.4),
          ),
          child: IconButton(
            tooltip: 'Keluar kuis',
            onPressed: onExit,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: AppColors.charcoal),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          children: [
            Text(
              materialTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.peachSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.peachBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: AppColors.terracotta,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    duration,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: onOpenGrid,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.charcoal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.grid_view_rounded, size: 14),
          label: const Text(
            'Soal',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({
    required this.currentIndex,
    required this.questions,
    required this.selectedAnswers,
    required this.flaggedIds,
  });

  final int currentIndex;
  final List<QuizQuestionModel> questions;
  final Map<String, int> selectedAnswers;
  final Set<String> flaggedIds;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Soal ${currentIndex + 1} dari ${questions.length}',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${selectedAnswers.length}/${questions.length} terjawab',
            style: const TextStyle(
              color: AppColors.inkSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Row(
        children: List.generate(questions.length, (index) {
          final question = questions[index];
          final answered = selectedAnswers.containsKey(question.id);
          final flagged = flaggedIds.contains(question.id);
          final color = index == currentIndex
              ? AppColors.charcoal
              : answered
              ? AppColors.peach
              : flagged
              ? AppColors.terracottaMuted
              : AppColors.borderLine;
          return Expanded(
            child: Container(
              height: index == currentIndex ? 10 : 7,
              margin: EdgeInsets.only(
                right: index == questions.length - 1 ? 0 : 5,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    ],
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.flagged,
    required this.onToggleFlag,
  });

  final int index;
  final String question;
  final bool flagged;
  final VoidCallback onToggleFlag;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.borderLine, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A16181D),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.lavenderCard,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(26),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              'PERTANYAAN #${(index + 1).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .45,
              ),
            ),
          ),
        ),
        Positioned(
          top: 7,
          right: 9,
          child: TextButton.icon(
            onPressed: onToggleFlag,
            style: TextButton.styleFrom(
              foregroundColor: flagged
                  ? AppColors.terracotta
                  : AppColors.inkSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              flagged ? Icons.flag_rounded : Icons.outlined_flag_rounded,
              size: 14,
            ),
            label: Text(
              flagged ? 'Ditandai' : 'Tandai',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 53, 19, 21),
          child: Text(
            question,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.charcoal : Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.charcoal : AppColors.borderLine,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.peach : AppColors.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.peach : AppColors.borderLine,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.peach,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SessionNavigation extends StatelessWidget {
  const _SessionNavigation({
    required this.canGoPrevious,
    required this.isLastQuestion,
    required this.canSubmit,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool isLastQuestion;
  final bool canSubmit;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: onPrevious,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.charcoal,
              disabledForegroundColor: AppColors.inkMeta,
              side: const BorderSide(color: AppColors.borderLine),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text(
              'Sebelumnya',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: isLastQuestion && !canSubmit
                  ? AppColors.inkMeta
                  : AppColors.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.only(left: 13, right: 7),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isLastQuestion ? 'Selesaikan Kuis' : 'Berikutnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ActionCircle(
                  icon: isLastQuestion
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: const BoxDecoration(
      color: AppColors.peach,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: AppColors.charcoal, size: 19),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFFDA29B)),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: Color(0xFF912018),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppBackButton(tooltip: 'Kembali', onPressed: onBack),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LatestScoreStrip extends StatelessWidget {
  const _LatestScoreStrip({required this.score, required this.count});

  final double? score;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderLine, width: 1.4),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.borderLine),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: AppColors.primaryDark,
            size: 19,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Skor latihan terbaru',
                style: TextStyle(
                  color: AppColors.inkMeta,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                score == null
                    ? 'Belum ada'
                    : '${score!.toStringAsFixed(1)} poin',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lavenderSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count× latihan',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
