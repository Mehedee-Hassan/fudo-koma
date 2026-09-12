import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/app_exception.dart';
import '../models/user_profile_model.dart';
import '../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../repositories/local/local_keys.dart';
import '../repositories/local/local_store.dart';

enum AuthStatus { unknown, signedOut, guest, authenticated, blocked }

class SessionController extends ChangeNotifier {
  SessionController(this._auth, {LocalStore? store}) : _store = store {
    _sub = _auth.watchCurrentUser().listen(_onProfile);
  }

  final AuthRepository _auth;
  final LocalStore? _store;
  StreamSubscription<UserProfileModel?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  UserProfileModel? _profile;
  String? _blockedReason;
  bool _busy = false;

  AuthStatus get status => _status;
  UserProfileModel? get profile => _profile;
  String? get blockedReason => _blockedReason;
  bool get busy => _busy;

  String? get currentUserId => _profile?.id;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isSignedIn => _status == AuthStatus.authenticated;
  bool get isOwner => isSignedIn && _profile?.role == UserRole.owner;
  bool get isAdmin => isSignedIn && _profile?.role == UserRole.admin;

  /// Follow, report and notification settings all require an identity: a
  /// device-scoped follow cannot survive a reinstall and cannot receive a push.
  bool get canFollow => isSignedIn;
  bool get canWrite => isSignedIn && !(_profile?.isBlocked ?? false);

  Future<void> restore() async {
    try {
      final restored = await _auth.restoreSession();
      if (restored != null) {
        _set(AuthStatus.authenticated, restored);
        return;
      }
      final wasGuest = _store?.getBool(LocalKeys.guestMode) ?? false;
      _set(wasGuest ? AuthStatus.guest : AuthStatus.signedOut, null);
    } on AuthException catch (error) {
      _blockedReason = error.message;
      _set(AuthStatus.blocked, null);
    } catch (error) {
      debugPrint('SessionController.restore failed: $error');
      _set(AuthStatus.signedOut, null);
    }
  }

  Future<void> continueAsGuest() async {
    await _store?.setBool(LocalKeys.guestMode, true);
    _set(AuthStatus.guest, null);
  }

  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        final profile = await _auth.signIn(email: email, password: password);
        await _store?.setBool(LocalKeys.guestMode, false);
        _set(AuthStatus.authenticated, profile);
      });

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) =>
      _run(() async {
        final profile = await _auth.register(
          email: email,
          password: password,
          displayName: displayName,
          role: role,
        );
        await _store?.setBool(LocalKeys.guestMode, false);
        _set(AuthStatus.authenticated, profile);
      });

  Future<void> signOut() async {
    await _auth.signOut();
    await _store?.setBool(LocalKeys.guestMode, false);
    _blockedReason = null;
    _set(AuthStatus.signedOut, null);
  }

  Future<void> updateProfile(UserProfileModel profile) async {
    await _auth.updateProfile(profile);
    _set(_status, profile);
  }

  Future<void> setProximityAlertsEnabled(bool enabled) async {
    final current = _profile;
    if (current == null) return;
    await updateProfile(current.copyWith(proximityAlertsEnabled: enabled));
  }

  Future<void> attachOwnedCart(String cartId) async {
    final current = _profile;
    if (current == null) return;
    await updateProfile(current.copyWith(ownedCartId: cartId));
  }

  /// Mid-session enforcement: if an admin flips `isBlocked`, the profile stream
  /// carries it here and the session ends immediately.
  void _onProfile(UserProfileModel? profile) {
    if (profile == null) {
      if (_status == AuthStatus.authenticated) {
        _set(AuthStatus.signedOut, null);
      }
      return;
    }
    if (profile.isBlocked) {
      _blockedReason =
          'This account has been blocked. Contact support for help.';
      unawaited(_auth.signOut());
      _set(AuthStatus.blocked, null);
      return;
    }
    if (_status == AuthStatus.authenticated || _status == AuthStatus.unknown) {
      _set(AuthStatus.authenticated, profile);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _set(AuthStatus status, UserProfileModel? profile) {
    _status = status;
    _profile = profile;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
