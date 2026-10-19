import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'summary_controller.dart';
import '../data/summary_repository.dart';

class SummaryScreen extends ConsumerWidget {
  final String materialId;

  const SummaryScreen({super.key, required this.materialId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider(materialId));
    const primary = Color(0xFF7560B5);
    const heading = Color(0xFF30283F);
    const secondary = Color(0xFF716B80);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FC),
      appBar: AppBar(
        title: const Text(
          'Ringkasan Materi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Regenerate ringkasan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              try {
                await ref
                    .read(summaryRepositoryProvider)
                    .regenerateSummary(materialId);
                ref.invalidate(summaryProvider(materialId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permintaan generate ulang dikirim...'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal regenerate: $e')),
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
          if (summary.overview.trim().isEmpty && summary.sections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ringkasan belum tersedia. Gunakan tombol refresh untuk membuat ulang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: secondary),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF2EDF9), Color(0xFFF7F5FC)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE7E2F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Overview materi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: heading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      summary.overview,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.65,
                        color: heading,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Rincian materi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: heading,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pahami konsep penting dari setiap bagian.',
                style: TextStyle(fontSize: 14, color: secondary),
              ),
              const SizedBox(height: 18),
              ...summary.sections.indexed.map((entry) {
                final index = entry.$1;
                final section = entry.$2;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7E2F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE3F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section.title,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.25,
                                fontWeight: FontWeight.bold,
                                color: heading,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'POIN KUNCI',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: .8,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...section.keyPoints.map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 7),
                                child: Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.55,
                                    color: heading,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (section.keyTerms.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFE7E2F0)),
                        const SizedBox(height: 14),
                        const Text(
                          'ISTILAH PENTING',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: .8,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...section.keyTerms.map(
                          (term) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: heading,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${term.term}: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: term.definition),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: primary)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat ringkasan:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
