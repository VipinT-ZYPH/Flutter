import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authServiceProvider = Provider((ref) => FirebaseAuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthController extends StateNotifier<bool> {
  final FirebaseAuthService _authService;
  AuthController(this._authService) : super(false);

  Future<void> signIn() async {
    state = true;
    await _authService.signInWithGoogle();
    state = false;
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
