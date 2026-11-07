import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _categories = [
    'Semua',
    'Upload Materi',
    'Ringkasan AI',
    'Flashcard',
    'Kuis',
    'AI Tutor',
    'Akun',
  ];

  static const _questions = [
    _HelpQuestion(
      category: 'Upload Materi',
      question: 'File apa yang bisa diunggah?',
      answer:
          'Kamu bisa mengunggah file PDF atau PPTX dengan ukuran maksimal 20 MB. Pastikan teks pada file dapat dibaca agar AI bisa memproses materinya.',
    ),
    _HelpQuestion(
      category: 'Upload Materi',
      question: 'Kenapa materi masih diproses atau gagal diproses?',
      answer:
          'Pemrosesan mencakup ekstraksi teks dan pembuatan fitur AI yang dipilih. Pastikan file tidak rusak dan teksnya dapat diekstrak. Jika statusnya gagal, buka kembali detail materi lalu coba proses lagi.',
    ),
    _HelpQuestion(
      category: 'Ringkasan AI',
      question: 'Dari mana ringkasan AI dibuat?',
      answer:
          'Ringkasan dibuat dari teks yang berhasil diekstrak dari materi yang kamu unggah. Gunakan pilihan Ringkas atau Detail untuk mengatur banyaknya poin yang ditampilkan.',
    ),
    _HelpQuestion(
      category: 'Ringkasan AI',
      question: 'Bagaimana cara membuat ulang ringkasan?',
      answer:
          'Buka halaman Ringkasan AI, lalu ketuk tombol muat ulang di bagian atas untuk meminta AI membuat ringkasan kembali.',
    ),
    _HelpQuestion(
      category: 'Flashcard',
      question: 'Bagaimana cara menggunakan flashcard?',
      answer:
          'Ketuk kartu untuk membalik dan melihat jawabannya. Setelah mempelajari kartu, tandai apakah kamu sudah memahaminya. Kamu bisa berpindah ke kartu berikutnya selama latihan.',
    ),
    _HelpQuestion(
      category: 'Kuis',
      question: 'Bagaimana cara menyelesaikan kuis?',
      answer:
          'Pilih satu jawaban untuk setiap soal. Setelah semua soal terjawab, kumpulkan kuis untuk melihat skor dan langsung membuka pembahasan.',
    ),
    _HelpQuestion(
      category: 'Kuis',
      question: 'Di mana saya bisa melihat hasil kuis sebelumnya?',
      answer:
          'Buka Kuis Latihan pada materi yang sama, lalu pilih salah satu kartu di bagian Riwayat Kuis untuk melihat pembahasan percobaan tersebut.',
    ),
    _HelpQuestion(
      category: 'AI Tutor',
      question: 'Bagaimana cara bertanya kepada AI Tutor?',
      answer:
          'Buka AI Tutor dari materi yang ingin dipelajari, lalu tulis pertanyaanmu. AI Tutor menggunakan materi yang dipilih sebagai konteks jawaban.',
    ),
    _HelpQuestion(
      category: 'Akun',
      question: 'Bagaimana cara mengubah nama atau NIM?',
      answer: 'Buka Profil, pilih Edit Profil, lalu perbarui nama atau NIM-mu.',
    ),
    _HelpQuestion(
      category: 'Akun',
      question: 'Bagaimana cara mengubah password?',
      answer:
          'Untuk akun email, gunakan pilihan Ubah Password pada halaman Profil. Jika masuk dengan Google atau SSO, perubahan password dilakukan melalui penyedia akun tersebut.',
    ),
  ];

  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final results = _questions.where((item) {
      final matchesCategory =
          _selectedCategory == 'Semua' || item.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty ||
          item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const StudyFeatureAppBar(
        title: 'Pusat Bantuan',
        subtitle: 'Panduan penggunaan & FAQ',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        children: [
          _introCard(),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari pertanyaan atau topik...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: Colors.white,
              hintStyle: const TextStyle(color: AppColors.inkMeta),
              prefixIconColor: AppColors.inkSecondary,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.borderLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Jelajahi topik',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      showCheckmark: false,
                      selectedColor: AppColors.charcoal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _selectedCategory == category
                            ? AppColors.charcoal
                            : AppColors.borderLine,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedCategory == category
                            ? Colors.white
                            : AppColors.inkSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${results.length} jawaban ditemukan',
            style: const TextStyle(
              color: AppColors.inkMeta,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (results.isEmpty)
            _emptyResults()
          else
            for (final question in results) ...[
              _questionCard(question),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          _studyHelpCard(context),
        ],
      ),
    );
  }

  Widget _introCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.charcoal,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: AppColors.charcoal,
            size: 25,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ada yang bisa dibantu?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Temukan panduan cepat untuk belajar dengan AI Tutor.',
                style: TextStyle(
                  color: Color(0xFFD5D8DE),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _questionCard(_HelpQuestion item) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderLine),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        iconColor: AppColors.primaryDark,
        collapsedIconColor: AppColors.inkMeta,
        title: Text(
          item.question,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lavenderSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.answer,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyResults() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderLine),
    ),
    child: const Column(
      children: [
        Icon(Icons.search_off_rounded, color: AppColors.inkMeta, size: 30),
        SizedBox(height: 8),
        Text(
          'Belum ada jawaban yang cocok.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Coba kata kunci lain atau pilih topik Semua.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkSecondary, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _studyHelpCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.peachSoft,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.peachBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Butuh bantuan memahami materi?',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih materi lalu tanyakan langsung kepada AI Tutor.',
          style: TextStyle(
            color: AppColors.inkSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go('/materials'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 17),
            label: const Text(
              'Buka daftar materi',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HelpQuestion {
  const _HelpQuestion({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}
