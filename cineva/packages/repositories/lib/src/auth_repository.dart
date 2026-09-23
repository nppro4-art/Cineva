abstract interface class AuthRepository {
  Stream<void> authStateChanges();

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  /// Nom affiché dans l'app (pseudonyme).
  ///
  /// L'abonné n'a pas à donner son état civil : ce nom est décoratif (en-tête du
  /// Profil, initiales de l'avatar) et modifiable à tout moment. L'identifiant de
  /// connexion, lui, ne change pas.
  Future<void> updateFullName({required String fullName});

  Future<void> resetPassword({required String email});

  Future<void> signOut();
}
