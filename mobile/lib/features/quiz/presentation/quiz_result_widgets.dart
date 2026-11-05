import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class QuizScoreHero extends StatelessWidget {
  const QuizScoreHero({
    super.key,
    required this.score,
    required this.correctCount,
    required this.total,
    required this.durationText,
    this.difficulty,
    this.previousScore,
    this.comparisonLoading = false,
  });

  final int score;
  final int correctCount;
  final int total;
  final String durationText;
  final String? difficulty;
  final int? previousScore;
  final bool comparisonLoading;

  @override
  Widget build(BuildContext context) {
    final wrongCount = total - correctCount;
    final difficultyLabel = switch (difficulty?.trim().toLowerCase()) {
      'mudah' || 'easy' => 'Mudah',
      'sedang' || 'medium' => 'Sedang',
      'sulit' || 'hard' => 'Sulit',
      _ => '—',
    };
    final comparison = switch ((previousScore, comparisonLoading)) {
      (_, true) => 'Membandingkan skor…',
      (null, false) => 'Percobaan pertama',
      (final previous?, false) when score > previous =>
        '+${score - previous} poin dari percobaan sebelumnya',
      (final previous?, false) when score < previous =>
        '${score - previous} poin dari percobaan sebelumnya',
      (_, false) => 'Skor sama dengan percobaan sebelumnya',
    };

    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 14,
                    color: AppColors.charcoal,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'HASIL EVALUASI',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$score',
                                style: const TextStyle(
                                  fontSize: 44,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                '/100',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .14),
                              ),
                            ),
                            child: Text(
                              comparison,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'KESULITAN',
                            style: TextStyle(
                              color: AppColors.peach,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            difficultyLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryPill(
                        label: 'Benar',
                        value: '$correctCount',
                        foreground: const Color(0xFF6EE7B7),
                        background: const Color(0x2210B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryPill(
                        label: 'Salah',
                        value: '$wrongCount',
                        foreground: const Color(0xFFFCA5A5),
                        background: const Color(0x22EF4444),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryPill(
                        label: difficulty == null || difficulty!.isEmpty
                            ? 'Durasi'
                            : 'Durasi • ${difficulty!}',
                        value: durationText,
                        foreground: AppColors.peach,
                        background: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
