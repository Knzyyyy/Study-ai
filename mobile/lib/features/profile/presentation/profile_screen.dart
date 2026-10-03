import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../home/presentation/home_screen.dart';
import '../../flashcard/presentation/flashcard_controller.dart';
import '../../quiz/domain/quiz_model.dart';
import '../../quiz/presentation/quiz_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double? weightedQuizScore(Iterable<QuizProgressModel> progress) {
  var attempts = 0;
  var total = 0.0;
  for (final item in progress) {
    if (item.count < 0) throw const FormatException('Invalid attempt count');
    if (item.count == 0) continue;
    final score = item.meanScore;
    if (score == null || !score.isFinite || score < 0 || score > 100) {
      throw const FormatException('Invalid quiz score');
    }
    attempts += item.count;
    total += score * item.count;
  }
  return attempts == 0 ? null : total / attempts;
}

class ProfileStatistics extends ConsumerWidget {
  const ProfileStatistics({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsListProvider);
    final progress = ref.watch(quizProgressProvider);
    return Column(
      children: [
        Row(
          children: [
            _metric(
              materials.when(
                skipLoadingOnRefresh: false,
                data: (items) => Text('${items.length}'),
                loading: () => const Text('Memuat...'),
                error: (_, _) =>
                    _retry(() => ref.invalidate(materialsListProvider)),
              ),
              'Dokumen diunggah',
              Icons.menu_book_outlined,
            ),
            const SizedBox(width: 10),
            _metric(
              progress.when(
                skipLoadingOnRefresh: false,
                data: (items) {
                  try {
                    final score = weightedQuizScore(items.values);
                    return Text(
                      score == null
                          ? 'Belum latihan'
                          : '${score.toStringAsFixed(1)}%',
                    );
                  } on FormatException {
                    return _retry(() => ref.invalidate(quizProgressProvider));
                  }
                },
                loading: () => const Text('Memuat...'),
                error: (_, _) =>
                    _retry(() => ref.invalidate(quizProgressProvider)),
              ),
              'Rata-rata skor kuis',
              Icons.track_changes_rounded,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ref
            .watch(flashcardReviewCountProvider)
            .when(
              skipLoadingOnRefresh: false,
              data: (count) => Text('Flashcard direview: $count'),
              loading: () => const Text('Flashcard direview: Memuat...'),
              error: (_, _) =>
                  _retry(() => ref.invalidate(flashcardReviewCountProvider)),
            ),
      ],
    );
  }

  Widget _retry(VoidCallback retry) => Column(
    children: [
      const Text('Gagal memuat'),
      TextButton(onPressed: retry, child: const Text('Coba lagi')),
    ],
  );

  Widget _metric(Widget value, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 19),
          const SizedBox(height: 12),
          value,
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

String? validateProfileName(String? value) {
  final name = value?.trim() ?? '';
  return name.length < 2 ||
          name.length > 100 ||
          RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)
      ? 'Nama harus 2–100 karakter tanpa karakter kontrol'
      : null;
}

String? validateNim(String? value) {
  final nim = value?.trim() ?? '';
  return nim.isNotEmpty && !RegExp(r'^[A-Za-z0-9.-]{3,30}$').hasMatch(nim)
      ? 'NIM opsional: 3–30 huruf, angka, titik atau tanda hubung'
      : null;
}

String? validatePassword(String? value) =>
    (value ?? '').length < 8 ? 'Password minimal 8 karakter' : null;

String? validatePasswordConfirmation(String? value, String password) =>
    value != password ? 'Konfirmasi password tidak cocok' : null;

class ProfileEditForm extends StatefulWidget {
  final String name;
  final String nim;
  final bool password;
  final Future<void> Function(String, String) save;
  const ProfileEditForm({
    super.key,
    this.name = '',
    this.nim = '',
    this.password = false,
    required this.save,
  });

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  final form = GlobalKey<FormState>();
  late final first = TextEditingController(
    text: widget.password ? '' : widget.name,
  );
  late final second = TextEditingController(
    text: widget.password ? '' : widget.nim,
  );
  bool saving = false;
  String? error;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.save(
        widget.password ? first.text : first.text.trim(),
        widget.password ? second.text : second.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Gagal menyimpan. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.password ? 'Ubah Password' : 'Edit Profil'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: first,
                enabled: !saving,
                obscureText: widget.password,
                autocorrect: !widget.password,
                enableSuggestions: !widget.password,
                decoration: InputDecoration(
                  labelText: widget.password ? 'Password baru' : 'Nama',
                ),
                validator: widget.password
                    ? validatePassword
                    : validateProfileName,
              ),
              TextFormField(
                controller: second,
                enabled: !saving,
                obscureText: widget.password,
                autocorrect: false,
                enableSuggestions: !widget.password,
                decoration: InputDecoration(
                  labelText: widget.password
                      ? 'Konfirmasi password'
                      : 'NIM (opsional)',
                ),
                validator: widget.password
                    ? (value) => validatePasswordConfirmation(value, first.text)
                    : validateNim,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: saving ? null : submit,
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

String? _metadataText(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notifications = true;

  Future<void> _edit({bool password = false}) async {
    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    if (user == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileEditForm(
        password: password,
        name:
            _metadataText(user.userMetadata?['full_name']) ??
            _metadataText(user.userMetadata?['name']) ??
            '',
        nim: _metadataText(user.userMetadata?['nim']) ?? '',
        save: (first, second) async {
          await auth.updateUser(
            password
                ? UserAttributes(password: first)
                : UserAttributes(data: {'full_name': first, 'nim': second}),
          );
        },
      ),
    );
    if (!mounted || saved != true) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(password ? 'Password diperbarui' : 'Profil diperbarui'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name =
        _metadataText(user?.userMetadata?['full_name']) ??
        _metadataText(user?.userMetadata?['name']) ??
        _metadataText(user?.email) ??
        'Pengguna';
    final nim = _metadataText(user?.userMetadata?['nim']);
    final email = user?.email ?? 'Belum ada email';
    const primary = Color(0xFF4F46E5);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFD1FAE5),
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        nim == null ? 'NIM belum diisi' : 'NIM: $nim',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Statistik Belajar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const ProfileStatistics(),
          const SizedBox(height: 24),
          const Text(
            'Pengaturan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, color: primary),
            title: const Text('Edit Profil'),
            subtitle: const Text('Nama dan NIM'),
            onTap: () => _edit(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: primary),
            title: const Text('Ubah Password'),
            subtitle: Text(
              user?.identities?.any(
                        (identity) => identity.provider == 'email',
                      ) ==
                      true
                  ? 'Password akun email; dapat memerlukan autentikasi ulang'
                  : 'Akun Google/SSO: kelola password melalui penyedia login',
            ),
            onTap:
                user?.identities?.any(
                      (identity) => identity.provider == 'email',
                    ) ==
                    true
                ? () => _edit(password: true)
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.notifications_none_rounded,
              color: primary,
            ),
            title: const Text('Notifikasi'),
            subtitle: const Text(
              'Preferensi tampilan saja; pengingat belum tersedia',
            ),
            value: notifications,
            activeThumbColor: primary,
            onChanged: (value) => setState(() => notifications = value),
          ),
          const SizedBox(height: 18),
          const Text(
            'Informasi Sistem',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _setting(
            Icons.info_outline,
            'Tentang MindSpark AI',
            'Versi 1.0.0-MVP',
          ),
          _setting(
            Icons.help_outline,
            'Pusat Bantuan',
            'Panduan penggunaan aplikasi',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            label: const Text(
              'Keluar dari akun',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(dynamic value) {
    final words = value.toString().trim().split(RegExp(r'\s+'));
    return words
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0])
        .join()
        .toUpperCase();
  }

  Widget _setting(IconData icon, String title, String subtitle) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: const Color(0xFF4F46E5)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
  );
}
