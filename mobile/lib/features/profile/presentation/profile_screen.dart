import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_feature_app_bar.dart';
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
    final reviews = ref.watch(flashcardReviewCountProvider);
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
                          : '${score.toStringAsFixed(1)}/100',
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
        const SizedBox(height: 12),
        _flashcardReviewCard(
          trailing: reviews.when(
            skipLoadingOnRefresh: false,
            data: (count) => _countBadge('$count Kartu'),
            loading: () => const Text(
              'Memuat...',
              style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
            ),
            error: (_, _) => IconButton(
              tooltip: 'Muat ulang statistik flashcard',
              onPressed: () => ref.invalidate(flashcardReviewCountProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _retry(VoidCallback retry) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Gagal memuat',
        style: TextStyle(fontSize: 11, color: AppColors.inkSecondary),
      ),
      TextButton(
        onPressed: retry,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Coba lagi', style: TextStyle(fontSize: 11)),
      ),
    ],
  );

  Widget _metric(Widget value, String label, IconData icon) {
    final peach = icon == Icons.menu_book_outlined;
    final accent = peach ? AppColors.peach : const Color(0xFFA8A0F7);
    final valueFontSize = value is Text && (value.data?.length ?? 0) > 7
        ? 16.0
        : 26.0;
    final styledValue = value is Text
        ? DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: valueFontSize,
              height: 1,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
            child: value,
          )
        : value;
    return Expanded(
      child: Container(
        height: 112,
        clipBehavior: Clip.antiAlias,
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
                width: 48,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Icon(icon, size: 19, color: AppColors.charcoal),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 38, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    styledValue,
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flashcardReviewCard({required Widget trailing}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.lavenderSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flashcard direview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              Text(
                'Total kartu yang sudah dilatih',
                style: TextStyle(fontSize: 11, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );

  Widget _countBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.charcoal,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.peach,
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
                Text(error!, style: const TextStyle(color: Color(0xFFEF4444))),
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
    const primary = AppColors.primaryDark;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: StudyFeatureAppBar(
        title: 'Profil',
        subtitle: 'Kelola identitas akademik & preferensi akunmu',
        showBackButton: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
        children: [
          const SizedBox(height: 4),
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7B0F7),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD5D8DE),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0x334B4F55)),
                ),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF383B40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        size: 17,
                        color: Color(0xFFB7B0F7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOMOR INDUK (NIM)',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: .55,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB8BEC8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nim ?? 'NIM belum diisi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (nim == null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _edit(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.peach,
                          backgroundColor: const Color(0xFF383B40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Lengkapi NIM →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _sectionPanel(
            label: 'PENGATURAN',
            icon: Icons.tune_rounded,
            accent: const Color(0xFFB7B0F7),
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.edit_outlined,
                  iconColor: const Color(0xFFE77943),
                  iconBackground: const Color(0xFFFFEFE5),
                  title: 'Edit Profil',
                  subtitle: 'Nama dan NIM',
                  onTap: () => _edit(),
                ),
                const SizedBox(height: 8),
                _settingTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.primaryDark,
                  iconBackground: AppColors.lavenderSoft,
                  title: 'Ubah Password',
                  subtitle:
                      user?.identities?.any(
                            (identity) => identity.provider == 'email',
                          ) ==
                          true
                      ? 'Password akun email; mungkin perlu autentikasi ulang'
                      : 'Akun Google/SSO: kelola password melalui penyedia login',
                  onTap:
                      user?.identities?.any(
                            (identity) => identity.provider == 'email',
                          ) ==
                          true
                      ? () => _edit(password: true)
                      : null,
                ),
                const SizedBox(height: 8),
                _notificationTile(primary),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionPanel(
            label: 'INFORMASI SISTEM',
            icon: Icons.info_outline_rounded,
            accent: AppColors.peach,
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.primaryDark,
                  iconBackground: AppColors.lavenderSoft,
                  title: 'Tentang AI Tutor',
                  subtitle: 'Versi 1.0.0-MVP',
                ),
                const SizedBox(height: 8),
                _settingTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFFE77943),
                  iconBackground: const Color(0xFFFFEFE5),
                  title: 'Pusat Bantuan',
                  subtitle: 'Panduan penggunaan & FAQ mahasiswa',
                  background: const Color(0xFFF3EEE7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _logoutButton(context),
        ],
      ),
    );
  }

  Widget _sectionPanel({
    required String label,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.borderLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomRight: Radius.circular(15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.charcoal),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: .5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ],
    ),
  );

  Widget _settingTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color background = const Color(0xFFFCFAF7),
  }) => Material(
    color: background,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAE2D8)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEAE2D8)),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _notificationTile(Color primary) => Container(
    constraints: const BoxConstraints(minHeight: 70),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFCFAF7),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEAE2D8)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEFE5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 19,
            color: Color(0xFFE77943),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Notifikasi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Preferensi tampilan saja; pengingat belum tersedia',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: notifications,
          activeThumbColor: Colors.white,
          activeTrackColor: primary,
          onChanged: (value) => setState(() => notifications = value),
        ),
      ],
    ),
  );

  Widget _logoutButton(BuildContext context) => Material(
    color: const Color(0xFFFFF3F2),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) context.go('/login');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFFFC3C5), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 18,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Keluar dari akun',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFC3C5)),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String _initials(dynamic value) {
    final words = value.toString().trim().split(RegExp(r'\s+'));
    return words
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0])
        .join()
        .toUpperCase();
  }
}
