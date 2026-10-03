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
