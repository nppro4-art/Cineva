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

  Future<void> resetPassword({required String email});

  Future<void> signOut();
}
