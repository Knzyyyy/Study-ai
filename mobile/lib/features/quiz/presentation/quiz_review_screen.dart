import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import '../data/quiz_repository.dart';
import '../domain/quiz_model.dart';
import 'quiz_result_widgets.dart';

final quizHistoryProvider = FutureProvider.autoDispose
    .family<List<QuizAttemptModel>, String>((ref, materialId) {
      return ref.watch(quizRepositoryProvider).getAttempts(materialId);
    });

final quizReviewProvider = FutureProvider.autoDispose
    .family<QuizReviewModel, String>((ref, attemptId) {
      return ref.watch(quizRepositoryProvider).getReview(attemptId);
    });

class QuizHistory extends ConsumerWidget {
  const QuizHistory({super.key, required this.materialId});

  final String materialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(quizHistoryProvider(materialId))
      .when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Column(
          children: [
            Text('Gagal memuat riwayat: $error'),
            TextButton(
              onPressed: () => ref.invalidate(quizHistoryProvider(materialId)),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
        data: (attempts) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Kuis',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (attempts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Ketuk untuk pembahasan',
                      style: TextStyle(
                        color: AppColors.inkSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (attempts.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: const Text(
                  'Belum ada riwayat kuis pada materi ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.inkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              for (final attempt in attempts) ...[
                _QuizHistoryCard(
                  attempt: attempt,
                  onTap: () => context.push<void>(
                    '/quiz-attempts/${attempt.id}/review?material_id='
                    '${Uri.encodeQueryComponent(materialId)}',
                  ),
                ),
                const SizedBox(height: 11),
              ],
          ],
        ),
      );
}

class _QuizHistoryCard extends StatelessWidget {
  const _QuizHistoryCard({required this.attempt, required this.onTap});

  final QuizAttemptModel attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = attempt.score;
    final scoreBackground = score >= 70
        ? AppColors.studySuccessSoft
        : score >= 40
        ? AppColors.peachSoft
        : const Color(0xFFFEF2F2);
    final scoreBorder = score >= 70
        ? AppColors.studySuccessBorder
        : score >= 40
        ? AppColors.peachBorder
        : const Color(0xFFFECACA);
    final scoreForeground = score >= 70
        ? AppColors.studySuccess
        : score >= 40
        ? AppColors.terracotta
        : const Color(0xFFB91C1C);
    final metadata = _quizMetadata(attempt.title);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderLine, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scoreBackground,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: scoreBorder, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SKOR',
                      style: TextStyle(
                        color: scoreForeground.withValues(alpha: .8),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        color: scoreForeground,
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _HistoryBadge(
                          label: metadata.difficulty.toUpperCase(),
                          background: AppColors.lavenderSoft,
                          border: AppColors.lavenderBorder,
                          foreground: AppColors.primaryDark,
                        ),
                        _HistoryBadge(
                          label: metadata.questionCount == null
                              ? 'SOAL'
                              : '${metadata.questionCount} SOAL',
                          background: AppColors.surface,
                          border: AppColors.borderLine,
                          foreground: AppColors.inkSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      attempt.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.inkMeta,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatAttemptDate(attempt.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkMeta,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.charcoal,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

({String difficulty, int? questionCount}) _quizMetadata(String title) {
  final match = RegExp(
    r'Quiz\s+(.+?)\s*-\s*(\d+)\s*Soal',
    caseSensitive: false,
  ).firstMatch(title);
  if (match == null) return (difficulty: 'Kuis', questionCount: null);
  final difficulty = match.group(1)?.trim() ?? 'Kuis';
  return (
    difficulty: difficulty.isEmpty ? 'Kuis' : difficulty,
    questionCount: int.tryParse(match.group(2) ?? ''),
  );
}

String _formatAttemptDate(DateTime? date) {
  if (date == null) return 'Tanggal tidak tersedia';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute';
}

class QuizReviewScreen extends ConsumerStatefulWidget {
  const QuizReviewScreen({
    super.key,
    required this.attemptId,
    this.materialId,
    this.durationSeconds,
    this.difficulty,
  });

  final String attemptId;
  final String? materialId;
  final int? durationSeconds;
  final String? difficulty;

  @override
  ConsumerState<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends ConsumerState<QuizReviewScreen> {
  String _filter = 'Semua';

  String get _durationText {
    final seconds = widget.durationSeconds;
    if (seconds == null || seconds < 0) return '—';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(quizReviewProvider(widget.attemptId));
    final materialTitle = widget.materialId == null
        ? null
        : ref
              .watch(materialsListProvider)
              .valueOrNull
              ?.where((material) => material.id == widget.materialId)
              .firstOrNull
              ?.title;
    final history = widget.materialId == null
        ? null
        : ref.watch(quizHistoryProvider(widget.materialId!));
    final previousScore = _previousScore(
      history?.valueOrNull,
      widget.attemptId,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Hasil & Pembahasan',
        subtitle: materialTitle ?? reviewAsync.valueOrNull?.attempt.title,
        onBack: () => context.pop(),
      ),
      body: reviewAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryDark),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.terracotta,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat pembahasan: $error',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(quizReviewProvider(widget.attemptId)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (review) => _buildReview(
          context,
          review: review,
          previousScore: previousScore,
          comparisonLoading: history?.isLoading ?? false,
        ),
      ),
    );
  }

  int? _previousScore(List<QuizAttemptModel>? attempts, String currentId) {
    if (attempts == null) return null;
    for (final attempt in attempts) {
      if (attempt.id != currentId) return attempt.score;
    }
    return null;
  }

  Widget _buildReview(
    BuildContext context, {
    required QuizReviewModel review,
    required int? previousScore,
    required bool comparisonLoading,
  }) {
    var correctCount = 0;
    for (final item in review.questions) {
      if (item.selectedIndex == item.correctIndex) correctCount++;
    }
    final total = review.questions.length;
    final filteredQuestions = <({int index, QuizReviewQuestionModel item})>[];
    for (var index = 0; index < review.questions.length; index++) {
      final item = review.questions[index];
      final isCorrect = item.selectedIndex == item.correctIndex;
      if (_filter == 'Benar' && !isCorrect) continue;
      if (_filter == 'Salah' && isCorrect) continue;
      filteredQuestions.add((index: index, item: item));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
      children: [
        QuizScoreHero(
          score: review.attempt.score,
          correctCount: correctCount,
          total: total,
          durationText: _durationText,
          difficulty: widget.difficulty,
          previousScore: previousScore,
          comparisonLoading: comparisonLoading,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Pembahasan Soal',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Benar', 'Salah'].map((filter) {
                  final active = _filter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: active,
                      showCheckmark: false,
                      selectedColor: AppColors.charcoal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: active
                            ? AppColors.charcoal
                            : AppColors.borderLine,
                      ),
                      labelStyle: TextStyle(
                        color: active ? Colors.white : AppColors.inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (filteredQuestions.isEmpty)
          const _EmptyReviewFilter()
        else
          for (final entry in filteredQuestions) ...[
            _ReviewQuestionCard(number: entry.index + 1, item: entry.item),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  const _ReviewQuestionCard({required this.number, required this.item});

  final int number;
  final QuizReviewQuestionModel item;

  @override
  Widget build(BuildContext context) {
    final isCorrect = item.selectedIndex == item.correctIndex;
    final questionNumber = number.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderLine, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A16181D),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.lavenderCard : AppColors.peach,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                'SOAL #$questionNumber',
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
            top: 9,
            right: 10,
            child: _StatusBadge(isCorrect: isCorrect),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 49, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.question.question,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.5,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 13),
                for (
                  var index = 0;
                  index < item.question.options.length;
                  index++
                ) ...[
                  _ReviewOption(
                    letter: _letter(index),
                    text: item.question.options[index],
                    correct: index == item.correctIndex,
                    selected: index == item.selectedIndex,
                  ),
                  if (index < item.question.options.length - 1)
                    const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                _ExplanationCard(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _letter(int index) => index < 4
      ? String.fromCharCode(65 + index)
      : String.fromCharCode(65 + index);
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: isCorrect ? AppColors.studySuccessSoft : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: isCorrect
            ? AppColors.studySuccessBorder
            : const Color(0xFFFECACA),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 13,
          color: isCorrect ? AppColors.studySuccess : const Color(0xFFB91C1C),
        ),
        const SizedBox(width: 4),
        Text(
          isCorrect ? 'Benar' : 'Salah',
          style: TextStyle(
            color: isCorrect ? AppColors.studySuccess : const Color(0xFFB91C1C),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.letter,
    required this.text,
    required this.correct,
    required this.selected,
  });

  final String letter;
  final String text;
  final bool correct;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color badgeBackground;
    final Color foreground;
    final String? tag;
    final Color? tagBackground;
    final Color? tagForeground;

    if (correct) {
      background = AppColors.studySuccessSoft;
      border = const Color(0xFF6EE7B7);
      badgeBackground = AppColors.studySuccess;
      foreground = const Color(0xFF065F46);
      tag = selected ? '✓ Jawabanmu Benar' : '✓ Kunci Jawaban';
      tagBackground = selected
          ? AppColors.studySuccess
          : const Color(0xFFD1FAE5);
      tagForeground = selected ? Colors.white : AppColors.studySuccess;
    } else if (selected) {
      background = const Color(0xFFFEF2F2);
      border = const Color(0xFFFCA5A5);
      badgeBackground = const Color(0xFFB91C1C);
      foreground = const Color(0xFF991B1B);
      tag = '✕ Jawabanmu';
      tagBackground = const Color(0xFFFEE2E2);
      tagForeground = const Color(0xFFB91C1C);
    } else {
      background = AppColors.surface;
      border = AppColors.borderLine;
      badgeBackground = Colors.white;
      foreground = AppColors.inkSecondary;
      tag = null;
      tagBackground = null;
      tagForeground = null;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(10),
              border: !correct && !selected
                  ? Border.all(color: AppColors.borderLine)
                  : null,
            ),
            child: Text(
              letter,
              style: TextStyle(
                color: correct || selected
                    ? Colors.white
                    : AppColors.inkSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 7),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: tagBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tagForeground,
                    fontSize: 9,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.item});

  final QuizReviewQuestionModel item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.lavenderSoft,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.lavenderBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primaryDark,
              size: 15,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'PEMBAHASAN AI',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.lavenderBorder),
              ),
              child: Text(
                item.pageBadge ?? 'Sumber tidak tersedia',
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          item.explanation,
          style: const TextStyle(
            color: AppColors.inkSecondary,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _EmptyReviewFilter extends StatelessWidget {
  const _EmptyReviewFilter();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderLine),
    ),
    child: const Column(
      children: [
        Icon(Icons.filter_alt_off_rounded, color: AppColors.inkMeta, size: 28),
        SizedBox(height: 8),
        Text(
          'Tidak ada soal pada filter ini.',
          style: TextStyle(
            color: AppColors.inkSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
