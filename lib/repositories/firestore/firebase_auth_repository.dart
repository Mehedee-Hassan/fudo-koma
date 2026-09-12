import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/app_exception.dart';
import '../../models/user_profile_model.dart';
import '../../models/user_role.dart';
import '../auth_repository.dart';
import 'firestore_refs.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance {
    _bind();
  }

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  final StreamController<UserProfileModel?> _controller =
      StreamController<UserProfileModel?>.broadcast();

  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  UserProfileModel? _current;

  @override
  UserProfileModel? get currentUser => _current;

  @override
  Stream<UserProfileModel?> watchCurrentUser() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Manual switchMap: auth state -> that user's profile document, so an admin
  /// blocking someone lands on their open session without adding rxdart.
  void _bind() {
    _authSub = _auth.authStateChanges().listen((user) {
      _profileSub?.cancel();
      _profileSub = null;

      if (user == null) {
        _current = null;
        _controller.add(null);
        return;
      }

      _profileSub =
          FirestoreRefs.users(_db).doc(user.uid).snapshots().listen((doc) {
        if (!doc.exists) return;
        final profile = UserProfileModel.fromMap(doc.data()!, doc.id);
        _current = profile;
        _controller.add(profile);
      });
    });
  }

  @override
  Future<UserProfileModel> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;

      final profile = UserProfileModel(
        id: uid,
        name: displayName.trim().isEmpty
            ? 'Follo Cart user'
            : displayName.trim(),
        email: email.trim().toLowerCase(),
        role: role,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      await FirestoreRefs.users(_db).doc(uid).set(profile.toMap());

      _current = profile;
      _controller.add(profile);
      return profile;
    } on fb.FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final doc = await FirestoreRefs.users(_db).doc(uid).get();

      final profile = doc.exists
          ? UserProfileModel.fromMap(doc.data()!, uid)
          : UserProfileModel(
              id: uid,
              name: credential.user?.displayName ?? 'Follo Cart user',
              email: email.trim().toLowerCase(),
              createdAt: DateTime.now(),
            );

      if (profile.isBlocked) {
        await _auth.signOut();
        throw const AuthException(
          AuthErrorCode.userBlocked,
          'This account has been blocked. Contact support for help.',
        );
      }

      await FirestoreRefs.users(_db).doc(uid).set(
        <String, dynamic>{'lastSeenAt': DateTime.now().toIso8601String()},
        SetOptions(merge: true),
      );

      _current = profile;
      _controller.add(profile);
      return profile;
    } on fb.FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<UserProfileModel?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await FirestoreRefs.users(_db).doc(user.uid).get();
    if (!doc.exists) return null;

    final profile = UserProfileModel.fromMap(doc.data()!, doc.id);
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
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> updateProfile(UserProfileModel profile) =>
      FirestoreRefs.users(_db)
          .doc(profile.id)
          .set(profile.toMap(), SetOptions(merge: true));

  @override
  Future<void> updateFcmToken({
    required String userId,
    String? token,
  }) =>
      FirestoreRefs.users(_db).doc(userId).set(
        <String, dynamic>{'fcmToken': token},
        SetOptions(merge: true),
      );

  /// Native codes are translated here, at the boundary, so no screen ever
  /// string-matches a Firebase error.
  static AuthException _translate(fb.FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => const AuthException(
          AuthErrorCode.emailInUse,
          'An account already exists for that email.',
        ),
      'invalid-email' => const AuthException(
          AuthErrorCode.invalidEmail,
          'Enter a valid email address.',
        ),
      'weak-password' => const AuthException(
          AuthErrorCode.weakPassword,
          'Use at least 8 characters for your password.',
        ),
      'user-disabled' => const AuthException(
          AuthErrorCode.userBlocked,
          'This account has been blocked. Contact support for help.',
        ),
      'network-request-failed' => const AuthException(
          AuthErrorCode.network,
          'No connection. Check your network and try again.',
        ),
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' =>
        const AuthException(
          AuthErrorCode.invalidCredentials,
          'That email and password do not match.',
        ),
      _ => AuthException(
          AuthErrorCode.unknown,
          error.message ?? 'Something went wrong. Try again.',
        ),
    };
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _controller.close();
  }
}
