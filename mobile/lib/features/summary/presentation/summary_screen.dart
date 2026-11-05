import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
import '../../home/presentation/home_screen.dart' show materialsListProvider;
import '../data/summary_repository.dart';
import '../domain/summary_model.dart';
import 'summary_controller.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.materialId});

  final String materialId;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  bool _showDetails = true;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(summaryProvider(widget.materialId));
    final materialTitle = ref
        .watch(materialsListProvider)
        .valueOrNull
        ?.where((material) => material.id == widget.materialId)
        .firstOrNull
        ?.title;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Ringkasan AI',
        subtitle: materialTitle,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        actions: [
          IconButton(
            tooltip: 'Buat ulang ringkasan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              try {
                await ref
                    .read(summaryRepositoryProvider)
                    .regenerateSummary(widget.materialId);
                ref.invalidate(summaryProvider(widget.materialId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Permintaan membuat ulang ringkasan dikirim.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membuat ulang: $error')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summaryAsync.when(
        data: (summary) {
          if (summary.overview.trim().isEmpty &&
              summary.sections.isEmpty &&
              summary.keyTerms.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ringkasan belum tersedia. Gunakan tombol buat ulang untuk mencoba lagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.inkSecondary),
                ),
              ),
            );
          }

          final pointCount = summary.sections.fold<int>(
            0,
            (total, section) => total + section.keyPoints.length,
          );
          final words = _readingText(summary).trim().split(RegExp(r'\s+'));
          final readingMinutes = (words.length / 190).ceil().clamp(1, 99);
          final hasSectionTerms = summary.sections.any(
            (section) => section.keyTerms.isNotEmpty,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _heroCard(
                materialTitle: materialTitle ?? 'Ringkasan materi',
                readingMinutes: readingMinutes,
                pointCount: pointCount,
              ),
              if (summary.overview.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                _overviewCard(summary.overview),
              ],
              if (summary.sections.isNotEmpty) ...[
                const SizedBox(height: 24),
                for (var index = 0; index < summary.sections.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _sectionCard(index, summary.sections[index]),
                  ),
              ],
              if (_showDetails &&
                  !hasSectionTerms &&
                  summary.keyTerms.isNotEmpty) ...[
                const SizedBox(height: 8),
                _termsBlock(summary.keyTerms),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryDark),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat ringkasan:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  String _readingText(SummaryModel summary) {
    final parts = <String>[summary.overview];
    for (final section in summary.sections) {
      parts.add(section.title);
      parts.addAll(
        _showDetails ? section.keyPoints : section.keyPoints.take(2),
      );
      if (_showDetails) {
        parts.addAll(section.examples);
        parts.addAll(
          section.keyTerms.expand((term) => [term.term, term.definition]),
        );
      }
    }
    return parts.join(' ');
  }

  Widget _heroCard({
    required String materialTitle,
    required int readingMinutes,
    required int pointCount,
  }) => Container(
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.charcoal,
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -48,
          bottom: -62,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.peach.withValues(alpha: .14),
                width: 16,
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _aiBadge()),
                const SizedBox(width: 10),
                _modeToggle(),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              materialTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 23,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(
                  icon: Icons.schedule_rounded,
                  label: 'Bacaan $readingMinutes menit',
                  color: const Color(0xFFB9B2FF),
                ),
                _metaChip(
                  icon: Icons.layers_rounded,
                  label: '$pointCount Poin Kunci',
                  color: AppColors.peach,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _aiBadge() => Container(
    constraints: const BoxConstraints(minHeight: 42),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 17, color: AppColors.charcoal),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Ringkasan AI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _modeToggle() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF383B40),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeOption('Ringkas', !_showDetails),
        _modeOption('Detail', _showDetails),
      ],
    ),
  );

  Widget _modeOption(String label, bool selected) => InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: () => setState(() => _showDetails = label == 'Detail'),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.charcoal : const Color(0xFFC3C8D0),
        ),
      ),
    ),
  );

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF383B40),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE3E5E8),
          ),
        ),
      ],
    ),
  );

  Widget _overviewCard(String overview) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5ED),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFFFB27D), width: 1.5),
    ),
    child: Stack(
      children: [
        Positioned(
          top: 4,
          right: 10,
          child: Icon(
            Icons.format_quote_rounded,
            size: 58,
            color: AppColors.peach.withValues(alpha: .22),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 18, 10),
              decoration: const BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 17, color: AppColors.charcoal),
                  SizedBox(width: 7),
                  Text(
                    'INTI MATERI · TL;DR',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .3,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Text(
                overview,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _sectionCard(int index, SectionSummary section) {
    final points = _showDetails
        ? section.keyPoints
        : section.keyPoints.take(2).toList();
    const pointColors = [
      Color(0xFFEDEAFF),
      Color(0xFFFFEFE5),
      Color(0xFFE9F1FF),
    ];
    const pointInkColors = [
      Color(0xFF665AE8),
      Color(0xFFE16D33),
      Color(0xFF4574C6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEAE2D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.peach,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOPIK PEMBAHASAN',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkMeta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFEAE2D8)),
                ),
                child: Text(
                  '${section.keyPoints.length} poin',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var pointIndex = 0; pointIndex < points.length; pointIndex++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFAF7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEDE5DB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pointColors[pointIndex % pointColors.length],
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${pointIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color:
                                pointInkColors[pointIndex %
                                    pointInkColors.length],
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          points[pointIndex],
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (!_showDetails && section.keyPoints.length > points.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showDetails = true),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  'Lihat ${section.keyPoints.length - points.length} poin lainnya',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          if (_showDetails && section.examples.isNotEmpty) ...[
            const SizedBox(height: 8),
            _examplesBlock(section.examples),
          ],
          if (_showDetails && section.keyTerms.isNotEmpty) ...[
            if (section.examples.isNotEmpty) const SizedBox(height: 16),
            if (section.examples.isEmpty) const SizedBox(height: 8),
            _termsBlock(section.keyTerms),
          ],
        ],
      ),
    );
  }

  Widget _examplesBlock(List<String> examples) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Contoh nyata',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.charcoal,
        ),
      ),
      const SizedBox(height: 8),
      for (final example in examples)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5ED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            example,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ),
    ],
  );

  Widget _termsBlock(List<TermDefinition> terms) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Istilah penting',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.charcoal,
        ),
      ),
      const SizedBox(height: 6),
      for (final term in terms)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.inkSecondary,
              ),
              children: [
                TextSpan(
                  text: '${term.term}  ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                TextSpan(text: term.definition),
              ],
            ),
          ),
        ),
    ],
  );
}
