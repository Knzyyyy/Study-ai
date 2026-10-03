import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signIn(email, password);
      state = const AsyncValue.data(null);
      return true; // Berhasil login
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return gagalLogin(e.toString());
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signInWithGoogle();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  bool gagalLogin(String error) {
    // Helper kecil jika butuh handling tambahan
    return false;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return AuthController(repo);
    });
