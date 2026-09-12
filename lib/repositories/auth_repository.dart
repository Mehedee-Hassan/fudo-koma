import '../models/user_profile_model.dart';
import '../models/user_role.dart';

/// Implementations translate their native failures into `AuthException` with a
/// backend-neutral `AuthErrorCode`, so no screen ever inspects a Firebase code.
abstract class AuthRepository {
  Stream<UserProfileModel?> watchCurrentUser();
  UserProfileModel? get currentUser;

  Future<UserProfileModel> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  });

  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  });

  /// Returns the signed-in profile if a session survived a restart.
  Future<UserProfileModel?> restoreSession();

  Future<void> signOut();
  Future<void> updateProfile(UserProfileModel profile);
  Future<void> updateFcmToken({required String userId, String? token});

  void dispose();
}
