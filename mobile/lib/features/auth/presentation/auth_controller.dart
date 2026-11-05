import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final passwordRecoveryModeProvider = StateProvider<bool>((ref) => false);
final registrationLoginFlowProvider = StateProvider<bool>((ref) => false);

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
      return false;
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
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return AuthController(repo);
    });
