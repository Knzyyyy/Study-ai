import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
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
    if (await ref
            .read(authControllerProvider.notifier)
            .signIn(email, password) &&
        mounted)
      context.go('/');
  }

  Future<void> _handleGoogleLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    const primary = Color(0xFF4F46E5);
    const heading = Color(0xFF111827);
    const secondary = Color(0xFF64748B);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(18, 40, 18, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MindSpark AI',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Asisten Belajar Cerdas Kuliahmu',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBFDFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5EAF2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMAIL KAMPUS / AKUN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: heading,
                          ),
                        ),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'nama@mahasiswa.ac.id',
                            prefixIcon: const Icon(
                              Icons.school_outlined,
                              size: 18,
                            ),
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'KATA SANDI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: heading,
                          ),
                        ),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(color: primary),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) =>
                                  setState(() => _rememberMe = value ?? false),
                              activeColor: primary,
                            ),
                            const Text(
                              'Ingat Saya',
                              style: TextStyle(fontSize: 11, color: secondary),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'Lupa Kata Sandi?',
                                style: TextStyle(fontSize: 11, color: primary),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : _handleLogin,
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: const Text('Masuk'),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'ATAU LANJUTKAN DENGAN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: secondary,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : _handleGoogleLogin,
                            icon: const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            label: const Text(
                              'Lanjutkan dengan Google',
                              style: TextStyle(color: heading),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: secondary),
                      children: [
                        TextSpan(text: 'Belum punya akun? '),
                        TextSpan(
                          text: 'Daftar gratis',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kebijakan Privasi   •   Panduan Etika Akademik',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
