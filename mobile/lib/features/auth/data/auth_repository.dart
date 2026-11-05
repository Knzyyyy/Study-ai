import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // Fungsi Login dengan Email & Password
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Gagal login: ${e.toString()}');
    }
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => _supabase.auth.signUp(
    email: email,
    password: password,
    data: {'full_name': fullName},
    emailRedirectTo: kIsWeb
        ? Uri.base.origin
        : 'io.supabase.tugaskhir://login-callback',
  );

  Future<void> sendPasswordResetEmail(String email) =>
      _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? '${Uri.base.origin}/reset-password'
            : 'io.supabase.tugaskhir://password-reset',
      );

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signInWithGoogle() async {
    final redirectTo = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.tugaskhir://login-callback';
    final started = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (!started) throw Exception('Gagal memulai login Google');
  }

  // Fungsi Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Cek apakah user sedang login
  User? get currentUser => _supabase.auth.currentUser;
}

// Provider Riverpod untuk AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});
