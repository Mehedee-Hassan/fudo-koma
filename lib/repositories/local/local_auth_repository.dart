import 'dart:async';

import '../../core/app_exception.dart';
import '../../core/id_generator.dart';
import '../../models/user_profile_model.dart';
import '../../models/user_role.dart';
import '../auth_repository.dart';
import 'local_keys.dart';
import 'local_password.dart';
import 'local_store.dart';

/// On-device accounts.
///
/// See `local_password.dart` for the honest limits of this storage. In short:
/// passwords are salted-and-hashed, never stored raw, but SharedPreferences is
/// plaintext at rest and SHA-256 is not a password KDF. Demo mode only.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final LocalStore _store;
  final StreamController<UserProfileModel?> _controller =
      StreamController<UserProfileModel?>.broadcast();

  UserProfileModel? _current;

  @override
  UserProfileModel? get currentUser => _current;

  @override
  Stream<UserProfileModel?> watchCurrentUser() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<UserProfileModel> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final normalized = _normalize(email);
    if (!_looksLikeEmail(normalized)) {
      throw const AuthException(
        AuthErrorCode.invalidEmail,
        'Enter a valid email address.',
      );
    }
    if (password.length < 8) {
      throw const AuthException(
        AuthErrorCode.weakPassword,
        'Use at least 8 characters for your password.',
      );
    }

    final users = _store.readCollection(LocalKeys.users);
    final taken = users.values.any((u) => _normalize(u['email'] as String? ?? '') == normalized);
    if (taken) {
      throw const AuthException(
        AuthErrorCode.emailInUse,
        'An account already exists for that email.',
      );
    }

    final id = newId('user');
    final salt = LocalPassword.newSalt();
    final profile = UserProfileModel(
      id: id,
      name: displayName.trim().isEmpty ? 'Follo Cart user' : displayName.trim(),
      email: normalized,
      role: role,
      createdAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );

    await _store.setDoc(LocalKeys.users, id, <String, dynamic>{
      ...profile.toMap(),
      'salt': salt,
      'passwordHash': LocalPassword.hash(password, salt),
    });

    await _setSession(profile);
    return profile;
  }

  @override
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = _normalize(email);
    final users = _store.readCollection(LocalKeys.users);

    for (final entry in users.entries) {
      if (_normalize(entry.value['email'] as String? ?? '') != normalized) {
        continue;
      }

      final salt = entry.value['salt'] as String? ?? '';
      final hash = entry.value['passwordHash'] as String? ?? '';
      if (!LocalPassword.verify(
        password: password,
        salt: salt,
        expectedHash: hash,
      )) {
        throw const AuthException(
          AuthErrorCode.invalidCredentials,
          'That email and password do not match.',
        );
      }

      final profile = UserProfileModel.fromMap(entry.value, entry.key);
      if (profile.isBlocked) {
        throw const AuthException(
          AuthErrorCode.userBlocked,
          'This account has been blocked. Contact support for help.',
        );
      }

      final seen = profile.copyWith(lastSeenAt: DateTime.now());
      await _persistProfile(seen);
      await _setSession(seen);
      return seen;
    }

    // Same message for unknown-email and wrong-password, so the store cannot
    // be probed for which addresses are registered.
    throw const AuthException(
      AuthErrorCode.invalidCredentials,
      'That email and password do not match.',
    );
  }

  @override
  Future<UserProfileModel?> restoreSession() async {
    final id = _store.getString(LocalKeys.session);
    if (id == null || id.isEmpty) return null;

    final data = _store.readDoc(LocalKeys.users, id);
    if (data == null) {
      await _store.remove(LocalKeys.session);
      return null;
    }

    final profile = UserProfileModel.fromMap(data, id);
    if (profile.isBlocked) {
      await signOut();
      throw const AuthException(
        AuthErrorCode.userBlocked,
        'This account has been blocked. Contact support for help.',
      );
    }

    _current = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _store.remove(LocalKeys.session);
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile(UserProfileModel profile) async {
    await _persistProfile(profile);
    if (_current?.id == profile.id) {
      _current = profile;
      _controller.add(profile);
    }
  }

  @override
  Future<void> updateFcmToken({
    required String userId,
    String? token,
  }) async {
    await _store.updateDoc(LocalKeys.users, userId, (current) {
      current['fcmToken'] = token;
      return current;
    });
  }

  /// Re-reads the stored record so an admin block lands on an open session.
  Future<UserProfileModel?> refreshCurrent() async {
    final id = _current?.id;
    if (id == null) return null;
    final data = _store.readDoc(LocalKeys.users, id);
    if (data == null) return null;
    final profile = UserProfileModel.fromMap(data, id);
    if (profile != _current) {
      _current = profile;
      _controller.add(profile);
    }
    return profile;
  }

  Future<void> _persistProfile(UserProfileModel profile) =>
      _store.updateDoc(LocalKeys.users, profile.id, (current) {
        // Merge, so `salt` and `passwordHash` survive a profile write.
        return <String, dynamic>{...current, ...profile.toMap()};
      });

  Future<void> _setSession(UserProfileModel profile) async {
    await _store.setString(LocalKeys.session, profile.id);
    _current = profile;
    _controller.add(profile);
  }

  static String _normalize(String email) => email.trim().toLowerCase();

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  void dispose() => _controller.close();
}
