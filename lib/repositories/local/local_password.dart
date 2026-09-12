import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// DEMO-GRADE CREDENTIAL HANDLING - read before relying on this.
///
/// SharedPreferences is plaintext at rest: an app-private XML file on Android,
/// an NSUserDefaults plist on iOS, `localStorage` on web. A rooted device, a
/// jailbroken phone, or browser devtools can read it.
///
/// The password itself is never stored - only a salted SHA-256 digest. But
/// SHA-256 is a *digest*, not a password KDF: there is no PBKDF2/Argon2 work
/// factor here, so a leaked store is trivially brute-forceable offline.
///
/// Local mode exists so the app runs with zero credentials. Use Firebase mode
/// for anything real.
abstract final class LocalPassword {
  static final Random _secure = Random.secure();

  static String newSalt() {
    final bytes = List<int>.generate(16, (_) => _secure.nextInt(256));
    return base64Encode(bytes);
  }

  static String hash(String password, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$password'));
    return base64Encode(digest.bytes);
  }

  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) =>
      hash(password, salt) == expectedHash;
}
