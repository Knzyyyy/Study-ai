import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/study_visuals.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'reset_password_bottom_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  StreamSubscription<AuthState>? _authSubscription;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      if (authState.event == AuthChangeEvent.signedIn &&
          authState.session != null &&
          mounted) {
        context.go('/');
      }
    }, onError: (Object error, StackTrace stackTrace) {});
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password wajib diisi')),
      );
      return;
    }
    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(email, password);
    if (!mounted) return;
    if (success) {
      context.go('/');
      return;
    }
    final error = ref.read(authControllerProvider).error;
    setState(() => _loginError = _loginErrorMessage(error));
  }

  String _loginErrorMessage(Object? error) {
    final message = error?.toString().toLowerCase() ?? '';
    if (message.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'Email atau kata sandi tidak cocok. Periksa kembali data masukmu.';
    }
    if (message.contains('email_not_confirmed')) {
      return 'Konfirmasi emailmu terlebih dahulu sebelum masuk.';
    }
    if (message.contains('socketexception') ||
        message.contains('timeoutexception') ||
        message.contains('network')) {
      return 'Koneksi bermasalah. Periksa internet lalu coba lagi.';
    }
    return 'Login belum berhasil. Periksa email dan kata sandimu, lalu coba lagi.';
  }

  Future<void> _handleGoogleLogin() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted || success) return;
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Login Google gagal')),
    );
  }

  Future<void> _showResetPassword() => showResetPasswordBottomSheet(
    context: context,
    initialEmail: _emailController.text.trim(),
    sendResetEmail: ref.read(authRepositoryProvider).sendPasswordResetEmail,
  );

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.borderLine, width: 1.5),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. CURVED PEACH HERO HEADER (Gaya Pinterest "My Courses")
                Container(
                  color: AppColors.peach,
                  padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pill Brand Identity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                                    color: AppColors.lavenderCard,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'AI Study Companion',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Headline Editorial & Ilustrasi Toga
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Belajar lebih\npaham, bukan\nsekadar baca.',
                                  style: TextStyle(
                                    fontSize: 27,
                                    height: 1.12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.charcoal,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Asisten Belajar Cerdas Kuliahmu: ringkasan, flashcard, & kuis instan.',
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
                          StudyIllustration(size: 92),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2 Kapsul Fitur
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _featurePill(
                            Icons.picture_as_pdf_outlined,
                            'PDF & PPTX',
                            dark: true,
                          ),
                          _featurePill(
                            Icons.bolt_rounded,
                            'Ringkasan • Flashcard • Kuis',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. OVERLAPPING CREAM SHEET + CUTOUT FORM CARD
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
                        // Card Form dengan Tab Cutout di Sudut Kiri Atas
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.borderLine,
                              width: 1.5,
                            ),
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
                              // Cutout Badge "AKSES MAHASISWA"
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
                                      topLeft: Radius.circular(22),
                                      bottomRight: Radius.circular(18),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 14,
                                        color: AppColors.charcoal,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'AKSES MAHASISWA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: AppColors.charcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Isi Form Login
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  50,
                                  18,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'EMAIL KAMPUS / AKUN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) {
                                        if (_loginError != null) {
                                          setState(() => _loginError = null);
                                        }
                                      },
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'nama@mahasiswa.ac.id',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        prefixIcon: const Icon(
                                          Icons.school_outlined,
                                          size: 20,
                                          color: AppColors.inkSecondary,
                                        ),
                                        border: inputBorder,
                                        enabledBorder: inputBorder,
                                        focusedBorder: inputBorder.copyWith(
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'KATA SANDI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      onChanged: (_) {
                                        if (_loginError != null) {
                                          setState(() => _loginError = null);
                                        }
                                      },
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan kata sandi',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 20,
                                          color: AppColors.inkSecondary,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Tampilkan kata sandi'
                                              : 'Sembunyikan kata sandi',
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                            color: AppColors.inkSecondary,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                        border: inputBorder,
                                        enabledBorder: inputBorder,
                                        focusedBorder: inputBorder.copyWith(
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_loginError != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF1F0),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFDA29B),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 19,
                                              color: Color(0xFFB42318),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(
                                              child: Text(
                                                _loginError!,
                                                style: const TextStyle(
                                                  color: Color(0xFF912018),
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),

                                    // Baris Ingat Saya & Lupa Kata Sandi
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) => setState(
                                              () =>
                                                  _rememberMe = value ?? false,
                                            ),
                                            activeColor: AppColors.primaryDark,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _rememberMe = !_rememberMe,
                                          ),
                                          child: const Text(
                                            'Ingat Saya',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.inkSecondary,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: _showResetPassword,
                                          child: const Text(
                                            'Lupa Kata Sandi?',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Tombol Utama Kapsul Charcoal + Panah Bulat Peach
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: FilledButton(
                                        onPressed: authState.isLoading
                                            ? null
                                            : _handleLogin,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.charcoal,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.only(
                                            left: 22,
                                            right: 8,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              authState.isLoading
                                                  ? 'Sedang masuk...'
                                                  : 'Masuk ke AI Tutor',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                color: AppColors.peach,
                                                shape: BoxShape.circle,
                                              ),
                                              child: authState.isLoading
                                                  ? const Padding(
                                                      padding: EdgeInsets.all(
                                                        10,
                                                      ),
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.2,
                                                            color: AppColors
                                                                .charcoal,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
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
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Divider "ATAU LANJUTKAN DENGAN"
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.borderLine),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'ATAU LANJUTKAN DENGAN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.inkMeta,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.borderLine),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tombol Google Kapsul
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: authState.isLoading
                                ? null
                                : _handleGoogleLogin,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(
                                color: AppColors.borderLine,
                                width: 1.5,
                              ),
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
                                const Text(
                                  'Lanjutkan dengan Google',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Footer Daftar & Kebijakan
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSecondary,
                              ),
                              children: [
                                TextSpan(text: 'Belum punya akun? '),
                                TextSpan(
                                  text: 'Daftar gratis',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Kebijakan Privasi   •   Panduan Etika Akademik',
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

  Widget _featurePill(IconData icon, String label, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.charcoal : const Color(0xFFFFB986),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark ? AppColors.charcoal : const Color(0xFFE9915F),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: dark ? AppColors.peach : AppColors.charcoal,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
