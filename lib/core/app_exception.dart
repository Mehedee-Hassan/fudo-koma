/// Backend-neutral auth failures.
///
/// Both the local and the Firebase repository translate their native errors
/// into these codes at the repository boundary, so no screen ever string-matches
/// a `FirebaseAuthException.code`. This is what makes the two backends
/// genuinely swappable behind the UI.
enum AuthErrorCode {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  userBlocked,
  network,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.code, this.message);

  final AuthErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
