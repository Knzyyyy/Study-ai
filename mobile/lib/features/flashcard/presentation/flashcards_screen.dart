import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import '../data/flashcard_repository.dart';
import '../domain/flashcard_model.dart';
import 'flashcard_controller.dart';

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
  bool sessionComplete = false;
  List<FlashcardModel>? retryDeck;

  Future<void> reviewCard(FlashcardModel card, bool understood) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref
          .read(flashcardRepositoryProvider)
          .reviewCard(widget.materialId, card.id, understood: understood);
      if (!mounted) return;
      ref.invalidate(flashcardsProvider(widget.materialId));
      ref.invalidate(flashcardReviewCountProvider);
      setState(() {
        saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    }
  }

  void startRetry(List<FlashcardModel> cards) {
    setState(() {
      retryDeck = cards
          .where((card) => card.reviewed && !card.studied)
          .toList();
      currentIndex = 0;
      showBack = false;
      sessionComplete = false;
    });
  }

  void startUnrated(List<FlashcardModel> cards) {
    setState(() {
      retryDeck = cards.where((card) => !card.reviewed).toList();
      currentIndex = 0;
      showBack = false;
      sessionComplete = false;
    });
  }

  Future<void> generateFlashcards() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI sedang membuat flashcard...')),
      );
      await ref
          .read(flashcardRepositoryProvider)
          .generateFlashcards(widget.materialId);
      ref.invalidate(flashcardsProvider(widget.materialId));
      if (!mounted) return;
      setState(() {
        currentIndex = 0;
        retryDeck = null;
        showBack = false;
        sessionComplete = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashcard berhasil dibuat.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal generate: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final flashcardsAsync = ref.watch(flashcardsProvider(widget.materialId));
    final materialTitle = ref
        .watch(materialsListProvider)
        .valueOrNull
        ?.where((material) => material.id == widget.materialId)
        .firstOrNull
        ?.title;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Latihan Flashcard',
        subtitle: materialTitle,
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Generate Flashcard dengan AI',
            onPressed: generateFlashcards,
          ),
        ],
      ),
      body: flashcardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) return _emptyState();
          final deck = retryDeck ?? cards;
          if (sessionComplete || deck.isEmpty || currentIndex >= deck.length) {
            return _completionState(cards);
          }

          final currentCard = deck[currentIndex];
          final understoodCount = cards
              .where((card) => card.reviewed && card.studied)
              .length;
          final retryCount = cards
              .where((card) => card.reviewed && !card.studied)
              .length;
          final unratedCount = cards.where((card) => !card.reviewed).length;

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _progressBar(deck.length),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statusChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Sudah paham',
                          count: understoodCount,
                          color: AppColors.studySuccess,
                          background: AppColors.studySuccessSoft,
                          border: AppColors.studySuccessBorder,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statusChip(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Perlu diulang',
                          count: retryCount,
                          color: AppColors.studyReview,
                          background: AppColors.studyReviewSoft,
                          border: AppColors.studyReviewBorder,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: AppColors.inkMeta,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Belum dinilai: $unratedCount',
                        style: const TextStyle(
                          color: AppColors.inkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = (constraints.maxHeight * .66)
                          .clamp(285.0, showBack ? 370.0 : 320.0)
                          .toDouble();
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                        child: Column(
                          children: [
                            SizedBox(
                              height: cardHeight,
                              child: _flashcard(currentCard),
                            ),
                            const SizedBox(height: 22),
                            _flipButton(),
                            if (showBack) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _reviewButton(
                                      label: 'Belum paham',
                                      icon: Icons.cancel_outlined,
                                      foreground: AppColors.studyReview,
                                      background: AppColors.studyReviewSoft,
                                      border: AppColors.studyReviewStrongBorder,
                                      onPressed: saving
                                          ? null
                                          : () =>
                                                reviewCard(currentCard, false),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _reviewButton(
                                      label: 'Sudah paham',
                                      icon: Icons.check_circle_outline_rounded,
                                      foreground: Colors.white,
                                      background: AppColors.studySuccessFill,
                                      border: AppColors.studySuccessFill,
                                      onPressed: saving
                                          ? null
                                          : () => reviewCard(currentCard, true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (saving) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(minHeight: 2),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _navigationFooter(deck.length),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryDark),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Flashcard gagal dimuat: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar(int total) {
    final progress = (currentIndex + 1) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: const Color(0xFFE8E3DB),
        color: AppColors.primary,
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required Color background,
    required Color border,
  }) => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _flashcard(FlashcardModel card) {
    final background = showBack ? AppColors.charcoal : Colors.white;
    final foreground = showBack ? Colors.white : AppColors.ink;
    final accent = showBack ? const Color(0xFF6EE7B7) : AppColors.primary;

    return GestureDetector(
      onTap: () => setState(() => showBack = !showBack),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: showBack ? AppColors.charcoal : const Color(0xFFC9C4FF),
            width: showBack ? 0 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showBack ? 'JAWABAN' : 'PERTANYAAN',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    letterSpacing: .3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBack && card.sourcePage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3D42),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Sumber: Hal. ${card.sourcePage}',
                          style: const TextStyle(
                            color: Color(0xFFFF8A65),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: showBack
                              ? Colors.white.withOpacity(.12)
                              : const Color(0xFFF0EEFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Kartu #${currentIndex + 1}',
                          style: TextStyle(
                            color: showBack
                                ? Colors.white70
                                : const Color(0xFF969BA6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showBack
                    ? SingleChildScrollView(
                        key: const ValueKey('answer'),
                        padding: const EdgeInsets.only(top: 17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.back,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 17,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (card.example != null &&
                                card.example!.trim().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A3D42),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Text(
                                  'Contoh: ${card.example}',
                                  style: const TextStyle(
                                    color: Color(0xFFE6E7EB),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : Center(
                        key: const ValueKey('question'),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              card.front,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 23,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _cardReviewStatus(card),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: showBack
                      ? const Color(0xFF8DB4D8)
                      : const Color(0xFF8A8E99),
                ),
                const SizedBox(width: 6),
                Text(
                  showBack
                      ? 'Ketuk kartu untuk kembali ke pertanyaan'
                      : 'Ketuk untuk melihat jawaban',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: showBack
                        ? const Color(0xFF8DB4D8)
                        : const Color(0xFF8A8E99),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardReviewStatus(FlashcardModel card) {
    final (label, icon, color, background) = switch ((
      card.reviewed,
      card.studied,
    )) {
      (true, true) => (
        'Sudah paham',
        Icons.check_circle_rounded,
        AppColors.studySuccess,
        AppColors.studySuccessSoft,
      ),
      (true, false) => (
        'Perlu diulang',
        Icons.bookmark_rounded,
        AppColors.studyReview,
        AppColors.studyReviewSoft,
      ),
      _ => (
        'Belum dinilai',
        Icons.radio_button_unchecked_rounded,
        AppColors.inkSecondary,
        AppColors.surfaceSubtle,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flipButton() => SizedBox(
    width: double.infinity,
    height: 54,
    child: OutlinedButton.icon(
      onPressed: () => setState(() => showBack = !showBack),
      icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
      label: const Text('Balik kartu'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.borderLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _reviewButton({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
    required Color border,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: 54,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: background.withOpacity(.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: BorderSide(color: border),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
  );

  Widget _navigationFooter(int total) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, color: AppColors.borderLine),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _navigationButton(
                label: 'Sebelumnya',
                arrow: '←',
                enabled: currentIndex > 0,
                onPressed: currentIndex > 0
                    ? () => setState(() {
                        currentIndex--;
                        showBack = false;
                      })
                    : null,
              ),
            ),
            SizedBox(
              width: 84,
              child: TextButton(
                onPressed: () => setState(() {
                  sessionComplete = true;
                  showBack = false;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text(
                  'Simulasi\nSelesai',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: _navigationButton(
                label: 'Berikutnya',
                arrow: '→',
                enabled: currentIndex < total - 1,
                onPressed: currentIndex < total - 1
                    ? () => setState(() {
                        currentIndex++;
                        showBack = false;
                      })
                    : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _navigationButton({
    required String label,
    required String arrow,
    required bool enabled,
    required VoidCallback? onPressed,
  }) => SizedBox(
    height: 66,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? AppColors.charcoal : AppColors.inkMeta,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: enabled ? AppColors.borderLine : const Color(0xFFF0ECE6),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          Text(arrow, style: const TextStyle(fontSize: 16, height: 1.1)),
        ],
      ),
    ),
  );

  Widget _completionState(List<FlashcardModel> cards) {
    final understoodCount = cards
        .where((card) => card.reviewed && card.studied)
        .length;
    final retryCount = cards
        .where((card) => card.reviewed && !card.studied)
        .length;
    final unratedCount = cards.where((card) => !card.reviewed).length;
    final isRetrySession = retryDeck != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          children: [
            const SizedBox(height: 26),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.studySuccessSoft,
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: AppColors.studySuccess,
                size: 58,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              isRetrySession ? 'Ulangan selesai!' : 'Sesi Flashcard Selesai!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 25,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isRetrySession
                  ? 'Kamu sudah mengulang ${retryDeck!.length} kartu. Terus berlatih agar makin ingat.'
                  : 'Sesi belajar untuk ${cards.length} kartu sudah selesai. Pertahankan progres dan lanjutkan latihanmu!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inkSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLine),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _completionStat(
                          '$understoodCount',
                          'Sudah paham',
                          AppColors.studySuccess,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 42,
                        color: AppColors.borderLine,
                      ),
                      Expanded(
                        child: _completionStat(
                          '$retryCount',
                          'Perlu diulang',
                          AppColors.studyReview,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum dinilai: $unratedCount kartu',
                    style: const TextStyle(
                      color: AppColors.inkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: retryCount == 0 ? null : () => startRetry(cards),
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  retryCount == 0
                      ? 'Tidak ada kartu untuk diulang'
                      : '${isRetrySession ? 'Ulangi lagi' : 'Ulangi yang belum paham'} ($retryCount kartu)',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.lavenderSoft,
                  disabledForegroundColor: AppColors.inkMeta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (unratedCount > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => startUnrated(cards),
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text('Lanjutkan kartu belum dinilai ($unratedCount)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkSecondary,
                    side: const BorderSide(color: AppColors.borderLine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/materials/${widget.materialId}/quiz'),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('Lanjut Uji Pemahaman di Kuis'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.lavenderBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (isRetrySession) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() {
                  retryDeck = null;
                  currentIndex = 0;
                  sessionComplete = false;
                }),
                child: const Text('Kembali ke semua flashcard'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _completionStat(String value, String label, Color color) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 25,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.inkSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.lavenderSoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.style_rounded,
              color: AppColors.primaryDark,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum ada flashcard untuk materi ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Buat kartu belajar dari materi ini dengan bantuan AI.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: generateFlashcards,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Buat Flashcard Sekarang'),
          ),
        ],
      ),
    ),
  );
}
