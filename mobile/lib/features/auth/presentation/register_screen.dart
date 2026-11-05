import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/study_visuals.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptedPolicies = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicies) {
      setState(
        () => _error = 'Setujui kebijakan dan panduan sebelum mendaftar.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    ref.read(registrationLoginFlowProvider.notifier).state = true;
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final response = await authRepository.signUp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (response.session != null) {
        try {
          await authRepository.signOut();
        } catch (_) {
          // Sign out clears the local session before its optional server call.
        }
      }
      if (!mounted) return;
      ref.read(registrationLoginFlowProvider.notifier).state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.session == null
                ? 'Cek email untuk konfirmasi akun, lalu masuk dengan email dan kata sandimu.'
                : 'Akun berhasil dibuat. Silakan masuk.',
          ),
        ),
      );
      context.go('/login');
    } catch (_) {
      if (mounted) {
        ref.read(registrationLoginFlowProvider.notifier).state = false;
        setState(() {
          _error =
              'Akun belum bisa dibuat. Periksa email dan koneksi, lalu coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    if (!_acceptedPolicies) {
      setState(
        () => _error = 'Setujui kebijakan dan panduan sebelum mendaftar.',
      );
      return;
    }
    setState(() => _error = null);
    final started = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted || started) return;
    final error = ref.read(authControllerProvider).error;
    setState(
      () => _error = error?.toString() ?? 'Pendaftaran dengan Google gagal.',
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderLine, width: 1.5),
    );
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: Icon(icon, size: 20, color: AppColors.inkSecondary),
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: const TextStyle(
        color: AppColors.inkMeta,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .4,
        color: AppColors.inkSecondary,
      ),
    ),
  );

  Widget _passwordField({required bool confirmation}) {
    final controller = confirmation
        ? _confirmPasswordController
        : _passwordController;
    final obscured = confirmation ? _obscureConfirmation : _obscurePassword;
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Kata sandi wajib diisi.';
        if (!confirmation && value.length < 6) {
          return 'Gunakan minimal 6 karakter.';
        }
        if (confirmation && value != _passwordController.text) {
          return 'Konfirmasi kata sandi belum cocok.';
        }
        return null;
      },
      decoration: _inputDecoration(
        hint: confirmation ? 'Ulangi kata sandi' : 'Minimal 6 karakter',
        icon: confirmation
            ? Icons.verified_user_outlined
            : Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          tooltip: obscured ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
          onPressed: () => setState(() {
            if (confirmation) {
              _obscureConfirmation = !_obscureConfirmation;
            } else {
              _obscurePassword = !_obscurePassword;
            }
          }),
          icon: Icon(
            obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(topInset),
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Column(
                      children: [
                        _formCard(),
                        const SizedBox(height: 18),
                        _dividerLabel('ATAU LANJUTKAN DENGAN'),
                        const SizedBox(height: 16),
                        _googleButton(authState.isLoading),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Sudah punya akun? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppColors.primaryDark,
                              ),
                              child: const Text(
                                'Masuk di sini',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Kebijakan Privasi   •   Panduan Etika Akademik',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMeta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(double topInset) => Container(
    color: AppColors.lavenderCard,
    padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 46),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBackButton(
                    tooltip: 'Kembali ke login',
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.peach,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Tutor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Akun Gratis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mulai perjalanan\nbelajar cerdasmu\nhari ini.',
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                      letterSpacing: -.6,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Buat akun mahasiswa untuk menyimpan course, ringkasan AI, dan progres kuis.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            TrophyBadgeIllustration(size: 100),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _featurePill(
              Icons.picture_as_pdf_outlined,
              'Sinkronisasi Materi',
              dark: true,
              iconColor: AppColors.primaryDark,
            ),
            _featurePill(
              Icons.auto_awesome_rounded,
              'Akses Penuh Fitur AI',
              lavender: true,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _featurePill(
    IconData icon,
    String label, {
    bool dark = false,
    bool lavender = false,
    Color? iconColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: dark
          ? AppColors.charcoal
          : lavender
          ? AppColors.lavenderCard
          : AppColors.peach,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: dark
            ? AppColors.charcoal
            : lavender
            ? AppColors.lavenderBorder
            : AppColors.peachBorder,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: iconColor ?? (dark ? AppColors.peach : AppColors.charcoal),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AppColors.charcoal,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _formCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borderLine, width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D16181D),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 14,
                  color: AppColors.charcoal,
                ),
                SizedBox(width: 6),
                Text(
                  'BUAT AKUN MAHASISWA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 50, 18, 20),
          child: _formContent(),
        ),
      ],
    ),
  );

  Widget _formContent() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('NAMA LENGKAP'),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Nama lengkap wajib diisi.'
              : null,
          decoration: _inputDecoration(
            hint: 'Contoh: Nadia Putri',
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel('EMAIL KAMPUS / AKUN'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          validator: _validateEmail,
          decoration: _inputDecoration(
            hint: 'nama@mahasiswa.ac.id',
            icon: Icons.school_outlined,
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel('BUAT KATA SANDI'),
        _passwordField(confirmation: false),
        const SizedBox(height: 16),
        _fieldLabel('KONFIRMASI KATA SANDI'),
        _passwordField(confirmation: true),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Checkbox(
                value: _acceptedPolicies,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _acceptedPolicies = value ?? false;
                        _error = null;
                      }),
                activeColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _submitting
                    ? null
                    : () => setState(() {
                        _acceptedPolicies = !_acceptedPolicies;
                        _error = null;
                      }),
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Saya menyetujui Kebijakan Privasi & Panduan Etika Akademik penggunaan AI.',
                    style: TextStyle(
                      color: AppColors.inkSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 5),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _submitting ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.only(left: 22, right: 8),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _submitting ? 'Membuat akun...' : 'Daftar ke AI Tutor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.lavenderCard,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.charcoal,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.charcoal,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _dividerLabel(String label) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.borderLine)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
            color: AppColors.inkMeta,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.borderLine)),
    ],
  );

  Widget _googleButton(bool authLoading) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      onPressed: _submitting || authLoading ? null : _registerWithGoogle,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.borderLine, width: 1.5),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.peachSoft,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEA4335),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Daftar dengan Google',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
