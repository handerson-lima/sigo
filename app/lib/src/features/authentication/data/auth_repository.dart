import '../../../sync/read_cache.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges();
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;

  AuthRepository(this._firebaseAuth);

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    final previous = _firebaseAuth.currentUser;
    if (previous != null && previous.email != email) {
      await clearReadCache(previous.uid);
    }
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    final uid = _firebaseAuth.currentUser?.uid;
    try {
      if (uid != null) await clearReadCache(uid);
    } finally {
      await _firebaseAuth.signOut();
    }
  }

  /// Altera voluntariamente a senha do usuário autenticado após reautenticação
  /// com a senha atual. Exige no mínimo 8 caracteres.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw Exception('A nova senha deve ter no mínimo 8 caracteres.');
    }

    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_traduzirErroAuth(e));
    }
  }

  static String _traduzirErroAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha atual incorreta.';
      case 'weak-password':
        return 'A nova senha é muito fraca. Utilize pelo menos 8 caracteres.';
      case 'requires-recent-login':
        return 'Sessão expirada. Entre novamente para alterar a senha.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns instantes e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return (e.message?.isNotEmpty ?? false)
            ? e.message!
            : 'Erro ao alterar senha.';
    }
  }
}
