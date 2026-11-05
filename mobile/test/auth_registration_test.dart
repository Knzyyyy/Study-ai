import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_akhir_mobpro/features/auth/data/auth_repository.dart';
import 'package:tugas_akhir_mobpro/features/auth/presentation/register_screen.dart';
import 'package:tugas_akhir_mobpro/features/auth/presentation/reset_password_bottom_sheet.dart';

class TestAuthRepository extends AuthRepository {
  TestAuthRepository()
    : super(
        SupabaseClient(
          'https://test.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int signUpCalls = 0;

  @override
  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    return AuthResponse();
  }
}

void main() {
  testWidgets('Registration returns to login and reports email confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestAuthRepository();
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Login page'))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Belajar lebih\npaham, bukan\nsekadar baca.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Kembali ke login'), findsOneWidget);
    expect(find.text('Akses Penuh Fitur AI'), findsOneWidget);
    expect(find.text('Daftar ke AI Tutor'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Nadia Putri');
    await tester.enterText(fields.at(1), 'nadia@example.com');
    await tester.enterText(fields.at(2), 'rahasia123');
    await tester.enterText(fields.at(3), 'rahasia123');
    await tester.ensureVisible(find.text('Daftar ke AI Tutor'));
    await tester.tap(find.text('Daftar ke AI Tutor'));
    await tester.pumpAndSettle();
    expect(
      find.text('Setujui kebijakan dan panduan sebelum mendaftar.'),
      findsOneWidget,
    );
    expect(repository.signUpCalls, 0);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Daftar ke AI Tutor'));
    await tester.tap(find.text('Daftar ke AI Tutor'));
    await tester.pumpAndSettle();
    expect(repository.signUpCalls, 1);
    expect(find.text('Login page'), findsOneWidget);
    expect(
      find.text(
        'Cek email untuk konfirmasi akun, lalu masuk dengan email dan kata sandimu.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Password reset bottom sheet sends the entered email', (
    tester,
  ) async {
    String? sentTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showResetPasswordBottomSheet(
                  context: context,
                  initialEmail: 'nadia@example.com',
                  sendResetEmail: (email) async => sentTo = email,
                ),
                child: const Text('Lupa Kata Sandi?'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Lupa Kata Sandi?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Kata Sandi'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'nadia@example.com',
    );
    await tester.tap(find.text('Kirim Tautan Reset'));
    await tester.pumpAndSettle();
    expect(sentTo, 'nadia@example.com');
    expect(find.text('Cek email kamu'), findsOneWidget);
  });
}
