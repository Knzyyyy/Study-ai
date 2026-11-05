import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuizQuestionItem {
  const QuizQuestionItem({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.topic = 'Konsep Utama',
    this.pageBadge = 'Hal. 10',
  });

  final String id;
  final String question;
  final List<String> options; // Pilihan A, B, C, D
  final int correctIndex;
  final String explanation;
  final String topic;
  final String pageBadge;
}

class QuizAttemptHistoryItem {
  const QuizAttemptHistoryItem({
    required this.id,
    required this.title,
    required this.score,
    required this.rawTimestamp,
    this.difficulty = 'Sedang',
    this.questionCount = 5,
  });

  final String id;
  final String title;
  final double score;
  final String rawTimestamp;
  final String difficulty;
  final int questionCount;
}

/// Helper untuk mengubah timestamp mentah "2026-11-05 17:15:39.265001"
/// menjadi teks rapi "5 Nov 2026 • 17:15"
String formatQuizTimestamp(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '-';
  final parsed = DateTime.tryParse(trimmed);
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
  if (parsed != null) {
    final local = parsed.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} • $hh:$mm';
  }
  return trimmed.split('.').first;
}

/// ============================================================================
/// 08B. LAYAR KUIS LATIHAN PER MATERI & RIWAYAT KUIS (PINTEREST BENTO STYLE)
/// ============================================================================
class MaterialQuizHistoryScreen extends StatelessWidget {
  const MaterialQuizHistoryScreen({
    super.key,
    this.materialTitle = 'Pertemuan 3',
    this.averageScore = 33.0,
    this.latestScore = 20.0,
    this.bestScore = 46.0,
    this.lastRecordedDate = '5/11/2026',
    this.historyItems = const [
      QuizAttemptHistoryItem(
        id: 'att-1',
        title: 'Quiz Sedang - 5 Soal',
        score: 20,
        rawTimestamp: '2026-11-05 17:15:39.265001',
        difficulty: 'Sedang',
        questionCount: 5,
      ),
      QuizAttemptHistoryItem(
        id: 'att-2',
        title: 'Quiz Sedang - 15 Soal',
        score: 46,
        rawTimestamp: '2026-11-05 17:08:18.811725',
        difficulty: 'Sedang',
        questionCount: 15,
      ),
    ],
    this.onStartQuiz,
    this.onTapHistoryItem,
  });

  final String materialTitle;
  final double? averageScore;
  final double? latestScore;
  final double? bestScore;
  final String? lastRecordedDate;
  final List<QuizAttemptHistoryItem> historyItems;
  final VoidCallback? onStartQuiz;
  final void Function(QuizAttemptHistoryItem item)? onTapHistoryItem;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 40 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER ATAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(
                        side: BorderSide(
                          color: AppColors.borderLine,
                          width: 1.5,
                        ),
                      ),
                      child: IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kuis Latihan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          materialTitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
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
                        size: 15,
                        color: AppColors.peach,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${historyItems.length} Latihan',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. HERO CARD "UJI PEMAHAMANMU" (Menggantikan ikon ungu mengambang)
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
                        horizontal: 16,
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
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.charcoal,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'EVALUASI MATERI',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.charcoal,
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
                      angle: 0.1,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.lavenderCard,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          size: 34,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 84),
                          child: Text(
                            'Uji pemahamanmu dari materi ini!',
                            style: TextStyle(
                              fontSize: 21,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(right: 84),
                          child: Text(
                            'Soal latihan dibuat otomatis oleh AI dari materi $materialTitle.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed:
                                onStartQuiz ??
                                () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => QuizSessionScreen(
                                        materialTitle: materialTitle,
                                      ),
                                    ),
                                  );
                                },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.peach,
                              foregroundColor: AppColors.charcoal,
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 8,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      size: 22,
                                      color: AppColors.charcoal,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Mulai Kuis Sekarang',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.charcoal,
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
                                    size: 19,
                                    color: Colors.white,
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
            const SizedBox(height: 20),

            // 3. INDIKATOR PEMAHAMAN (Menggantikan 3 baris teks polos bertumpuk)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Indikator Pemahaman',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                if (lastRecordedDate != null)
                  Text(
                    'Terakhir: $lastRecordedDate',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMeta,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCutoutStat(
                    label: 'Rata-rata skor',
                    value: averageScore == null
                        ? '—'
                        : '${averageScore!.toStringAsFixed(1)}%',
                    icon: Icons.pie_chart_outline_rounded,
                    peach: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCutoutStat(
                    label: 'Skor terbaik',
                    value: bestScore == null
                        ? '—'
                        : bestScore!.toStringAsFixed(1),
                    icon: Icons.emoji_events_outlined,
                    peach: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLine, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLine),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Skor latihan terbaru',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMeta,
                            ),
                          ),
                          Text(
                            latestScore == null
                                ? 'Belum ada'
                                : '${latestScore!.toStringAsFixed(1)} poin',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${historyItems.length}x latihan',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 4. DAFTAR RIWAYAT KUIS (BENTO CARDS DENGAN SCORE BOX & TANGGAL BERSIH)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Kuis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Ketuk untuk pembahasan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (historyItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: const Text(
                  'Belum ada riwayat kuis pada materi ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSecondary,
                  ),
                ),
              )
            else
              for (final item in historyItems) ...[
                _buildHistoryItemCard(context, item),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildCutoutStat({
    required String label,
    required String value,
    required IconData icon,
    required bool peach,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: peach ? AppColors.peachSoft : AppColors.lavenderSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: peach ? AppColors.peachBorder : AppColors.lavenderBorder,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                color: peach ? AppColors.peach : AppColors.lavenderCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Icon(icon, size: 18, color: AppColors.charcoal),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItemCard(
    BuildContext context,
    QuizAttemptHistoryItem item,
  ) {
    final isGood = item.score >= 70;
    final isMid = item.score >= 40 && item.score < 70;

    final scoreBg = isGood
        ? const Color(0xFFECFDF5)
        : isMid
            ? AppColors.peachSoft
            : const Color(0xFFFEF2F2);
    final scoreBorder = isGood
        ? const Color(0xFFA7F3D0)
        : isMid
            ? AppColors.peachBorder
            : const Color(0xFFFECACA);
    final scoreText = isGood
        ? const Color(0xFF047857)
        : isMid
            ? AppColors.terracotta
            : const Color(0xFFB91C1C);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (onTapHistoryItem != null) {
            onTapHistoryItem!(item);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizReviewScreen(
                  materialTitle: materialTitle,
                  questions: _sampleQuestions,
                  userAnswers: const {0: 1, 1: 0},
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderLine, width: 1.5),
          ),
          child: Row(
            children: [
              // Kotak Skor Dominan di Kiri
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scoreBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scoreBorder, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SKOR',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: scoreText.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      item.score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: scoreText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Detail Sesi & Tanggal Rapi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.lavenderBorder),
                          ),
                          child: Text(
                            item.difficulty.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.borderLine),
                          ),
                          child: Text(
                            '${item.questionCount} Soal',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
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
                            formatQuizTimestamp(item.rawTimestamp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMeta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Tombol Panah Bulat di Kanan
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// 09. LAYAR SESI MENGERJAKAN KUIS (QUIZ TAKING SCREEN)
/// ============================================================================
class QuizSessionScreen extends StatefulWidget {
  const QuizSessionScreen({
    super.key,
    this.materialTitle = 'Normalisasi Database.pdf',
    this.questions = _sampleQuestions,
  });

  final String materialTitle;
  final List<QuizQuestionItem> questions;

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {0: 1, 1: 0, 2: 1};
  final Set<int> _flaggedIndices = {};

  static const _letters = ['A', 'B', 'C', 'D'];

  void _openResultScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizReviewScreen(
          materialTitle: widget.materialTitle,
          questions: widget.questions,
          userAnswers: Map<int, int>.from(_selectedAnswers),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final total = widget.questions.length;
    final currentQ = widget.questions[_currentIndex];
    final selectedOption = _selectedAnswers[_currentIndex];
    final isFlagged = _flaggedIndices.contains(_currentIndex);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 32 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER FOKUS (Tombol Keluar, Kapsul Timer, Daftar Soal)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.borderLine, width: 1.5),
                  ),
                  child: IconButton(
                    tooltip: 'Keluar kuis',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.peachSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.peachBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: AppColors.terracotta,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '11:40',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showQuestionGridSheet(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.charcoal,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: AppColors.peach,
                  ),
                  label: const Text(
                    'Soal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. SEGMENTED PROGRESS BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soal ${_currentIndex + 1} dari $total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  currentQ.topic,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(total, (i) {
                final isCurrent = i == _currentIndex;
                final isAnswered = _selectedAnswers.containsKey(i);
                return Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.charcoal
                          : isAnswered
                              ? AppColors.primary
                              : const Color(0xFFE5DFD5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // 3. KARTU PERTANYAAN DENGAN CUTOUT CORNER TAB
            Container(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.lavenderCard,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(26),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text(
                        'PERTANYAAN #${(_currentIndex + 1).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        setState(() {
                          if (isFlagged) {
                            _flaggedIndices.remove(_currentIndex);
                          } else {
                            _flaggedIndices.add(_currentIndex);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isFlagged
                              ? AppColors.peachSoft
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isFlagged
                                ? AppColors.peach
                                : AppColors.borderLine,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 13,
                              color: isFlagged
                                  ? AppColors.terracotta
                                  : AppColors.inkSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFlagged ? 'Ditandai' : 'Tandai',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isFlagged
                                    ? AppColors.terracotta
                                    : AppColors.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
                    child: Text(
                      currentQ.question,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. PILIHAN JAWABAN A, B, C, D
            for (var oIdx = 0; oIdx < currentQ.options.length; oIdx++) ...[
              _buildOptionTile(
                letter: _letters[oIdx],
                text: currentQ.options[oIdx],
                isSelected: selectedOption == oIdx,
                onTap: () => setState(() {
                  _selectedAnswers[_currentIndex] = oIdx;
                }),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 10),

            // 5. TOMBOL NAVIGASI BAWAH
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _currentIndex > 0
                        ? () => setState(() => _currentIndex--)
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        if (_currentIndex < total - 1) {
                          setState(() => _currentIndex++);
                        } else {
                          _openResultScreen();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.charcoal,
                        padding: const EdgeInsets.only(left: 22, right: 8),
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _currentIndex < total - 1
                                ? 'Soal Berikutnya'
                                : 'Selesaikan & Pembahasan',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.peach,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _currentIndex < total - 1
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_rounded,
                              color: AppColors.charcoal,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String letter,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.charcoal : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.charcoal : AppColors.borderLine,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.peach : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.borderLine),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.peach : AppColors.borderLine,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Container(
                        width: 10,
                        height: 10,
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

  void _showQuestionGridSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daftar Nomor Soal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(widget.questions.length, (i) {
                final answered = _selectedAnswers.containsKey(i);
                return InkWell(
                  onTap: () {
                    setState(() => _currentIndex = i);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: answered ? AppColors.charcoal : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLine),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: answered ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 10. LAYAR HASIL & PEMBAHASAN KUIS (MENAMPILKAN SEMUA PILIHAN A, B, C, D)
/// ============================================================================
class QuizReviewScreen extends StatefulWidget {
  const QuizReviewScreen({
    super.key,
    required this.materialTitle,
    required this.questions,
    required this.userAnswers,
    this.onRetryQuiz,
  });

  final String materialTitle;
  final List<QuizQuestionItem> questions;
  final Map<int, int> userAnswers;
  final VoidCallback? onRetryQuiz;

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  String _filter = 'Semua'; // Semua | Benar | Salah
  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final total = widget.questions.length;

    var correctCount = 0;
    for (var i = 0; i < total; i++) {
      if (widget.userAnswers[i] == widget.questions[i].correctIndex) {
        correctCount++;
      }
    }
    final wrongCount = total - correctCount;
    final score = total == 0 ? 0 : ((correctCount / total) * 100).round();

    final filteredIndices = <int>[];
    for (var i = 0; i < total; i++) {
      final isCorrect =
          widget.userAnswers[i] == widget.questions[i].correctIndex;
      if (_filter == 'Benar' && !isCorrect) continue;
      if (_filter == 'Salah' && isCorrect) continue;
      filteredIndices.add(i);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 40 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER ATAS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.borderLine, width: 1.5),
                  ),
                  child: IconButton(
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      'Hasil & Pembahasan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      widget.materialTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: AppColors.peachSoft,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.peachBorder),
                  ),
                  child: IconButton(
                    tooltip: 'Ulangi kuis',
                    onPressed:
                        widget.onRetryQuiz ??
                        () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.replay_rounded,
                      size: 19,
                      color: AppColors.terracotta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. SCORE HERO CARD (CHARCOAL + CUTOUT TAB PEACH)
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
                        horizontal: 16,
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
                              letterSpacing: 0.4,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$score',
                                        style: const TextStyle(
                                          fontSize: 44,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        '/100',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    score >= 70
                                        ? 'Bagus! Dasar konsepnya sudah kamu pahami.'
                                        : 'Terus berlatih! Tinjau opsi jawaban di bawah.',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Column(
                                children: [
                                  Text(
                                    'LEVEL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.peach,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sedang',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _heroStatBox(
                                value: '$correctCount',
                                label: 'Benar',
                                textColor: const Color(0xFF6EE7B7),
                                bgColor: const Color(0x2210B981),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroStatBox(
                                value: '$wrongCount',
                                label: 'Salah',
                                textColor: const Color(0xFFFCA5A5),
                                bgColor: const Color(0x22EF4444),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroStatBox(
                                value: '12m',
                                label: 'Durasi',
                                textColor: AppColors.peach,
                                bgColor: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. FILTER PEMBAHASAN (Semua, Benar, Salah)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembahasan Soal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Row(
                  children: ['Semua', 'Benar', 'Salah'].map((f) {
                    final active = _filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : AppColors.ink,
                          ),
                        ),
                        selected: active,
                        selectedColor: AppColors.charcoal,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. DAFTAR KARTU PEMBAHASAN (MENAMPILKAN KEEMPAT OPSI A, B, C, D)
            for (final qIndex in filteredIndices) ...[
              _buildQuestionReviewCard(
                questionNumber: qIndex + 1,
                item: widget.questions[qIndex],
                userChoiceIndex: widget.userAnswers[qIndex],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroStatBox({
    required String value,
    required String label,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Pembahasan per Soal yang menampilkan seluruh pilihan A, B, C, D
  Widget _buildQuestionReviewCard({
    required int questionNumber,
    required QuizQuestionItem item,
    required int? userChoiceIndex,
  }) {
    final isQuestionCorrect = userChoiceIndex == item.correctIndex;
    final numStr = questionNumber.toString().padLeft(2, '0');

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
          // Cutout Badge Nomor Soal
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isQuestionCorrect
                    ? AppColors.lavenderCard
                    : AppColors.peach,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                'SOAL #$numStr • ${item.topic.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ),

          // Status Pill Benar / Salah di Kanan Atas
          Positioned(
            top: 10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isQuestionCorrect
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isQuestionCorrect
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isQuestionCorrect
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    size: 13,
                    color: isQuestionCorrect
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isQuestionCorrect ? 'Benar' : 'Salah',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isQuestionCorrect
                          ? const Color(0xFF047857)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Isi Soal, Keempat Opsi A-B-C-D, dan Penjelasan AI
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.question,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),

                // MENAMPILKAN SELURUH PILIHAN A, B, C, D
                for (var oIdx = 0; oIdx < item.options.length; oIdx++) ...[
                  _buildReviewOptionRow(
                    letter: _letters[oIdx],
                    text: item.options[oIdx],
                    isCorrectOption: oIdx == item.correctIndex,
                    isUserSelected: oIdx == userChoiceIndex,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),

                // Kotak Pembahasan AI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.lavenderBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 15,
                                color: AppColors.primaryDark,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PEMBAHASAN AI',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.lavenderBorder,
                              ),
                            ),
                            child: Text(
                              item.pageBadge,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.explanation,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Baris setiap opsi (A, B, C, atau D) di dalam kartu Pembahasan
  Widget _buildReviewOptionRow({
    required String letter,
    required String text,
    required bool isCorrectOption,
    required bool isUserSelected,
  }) {
    Color bgColor = AppColors.surface;
    Color borderColor = AppColors.borderLine;
    Color letterBg = Colors.white;
    Color letterFg = AppColors.inkSecondary;
    Color textColor = AppColors.inkSecondary;
    String? statusTag;
    Color? tagBg;
    Color? tagFg;

    if (isCorrectOption && isUserSelected) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF6EE7B7);
      letterBg = const Color(0xFF047857);
      letterFg = Colors.white;
      textColor = const Color(0xFF065F46);
      statusTag = '✓ Jawabanmu Benar';
      tagBg = const Color(0xFF047857);
      tagFg = Colors.white;
    } else if (isCorrectOption) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF6EE7B7);
      letterBg = const Color(0xFF047857);
      letterFg = Colors.white;
      textColor = const Color(0xFF065F46);
      statusTag = '✓ Kunci Jawaban';
      tagBg = const Color(0xFFD1FAE5);
      tagFg = const Color(0xFF047857);
    } else if (isUserSelected && !isCorrectOption) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFCA5A5);
      letterBg = const Color(0xFFB91C1C);
      letterFg = Colors.white;
      textColor = const Color(0xFF991B1B);
      statusTag = '✕ Jawabanmu';
      tagBg = const Color(0xFFFEE2E2);
      tagFg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: letterBg,
              borderRadius: BorderRadius.circular(10),
              border: (!isCorrectOption && !isUserSelected)
                  ? Border.all(color: AppColors.borderLine)
                  : null,
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: letterFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (statusTag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusTag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: tagFg,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const List<QuizQuestionItem> _sampleQuestions = [
  QuizQuestionItem(
    id: 'q1',
    question: 'Apa tujuan utama dari proses normalisasi database relasional?',
    options: [
      'Menggandakan data pada setiap tabel agar cadangan lebih banyak.',
      'Mengurangi redundansi data dan mencegah anomali saat modifikasi data.',
      'Menghapus seluruh relasi antartabel agar query tanpa JOIN.',
      'Mengubah semua atribut biasa menjadi primary key.',
    ],
    correctIndex: 1,
    explanation:
        'Normalisasi bertujuan meminimalkan duplikasi (redundansi) dan mencegah terjadinya insertion, update, serta deletion anomaly.',
    topic: 'Konsep Dasar',
    pageBadge: 'Hal. 4',
  ),
  QuizQuestionItem(
    id: 'q2',
    question:
        'Anomali ketika penghapusan data mahasiswa secara tidak sengaja ikut menghapus data master program studi disebut…',
    options: [
      'Insertion Anomaly (Anomali Penyisipan)',
      'Update Anomaly (Anomali Pembaruan)',
      'Deletion Anomaly (Anomali Penghapusan)',
      'Selection Anomaly (Anomali Pemilihan)',
    ],
    correctIndex: 2,
    explanation:
        'Deletion anomaly terjadi saat penghapusan satu baris menyebabkan hilangnya informasi master penting lain yang tersimpan di baris yang sama.',
    topic: 'Anomali Data',
    pageBadge: 'Hal. 6',
  ),
];