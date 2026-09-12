import '../core/backend_mode.dart';
import 'auth_repository.dart';
import 'cart_repository.dart';
import 'follow_repository.dart';
import 'media_repository.dart';
import 'moderation_repository.dart';
import 'notification_repository.dart';
import 'local/local_auth_repository.dart';
import 'local/local_cart_repository.dart';
import 'local/local_follow_repository.dart';
import 'local/local_media_repository.dart';
import 'local/local_moderation_repository.dart';
import 'local/local_notification_repository.dart';
import 'local/local_store.dart';
import 'firestore/firebase_auth_repository.dart';
import 'firestore/firebase_media_repository.dart';
import 'firestore/firestore_cart_repository.dart';
import 'firestore/firestore_follow_repository.dart';
import 'firestore/firestore_moderation_repository.dart';
import 'firestore/firestore_notification_repository.dart';

/// The single seam between the app and its storage.
///
/// This replaces the old `FirestoreService`, which existed to be "swapped for
/// real queries later" but had no interface and no second implementation.
class RepositoryBundle {
  const RepositoryBundle({
    required this.mode,
    required this.auth,
    required this.carts,
    required this.follows,
    required this.notifications,
    required this.moderation,
    required this.media,
  });

  final BackendMode mode;
  final AuthRepository auth;
  final CartRepository carts;
  final FollowRepository follows;
  final NotificationRepository notifications;
  final ModerationRepository moderation;
  final MediaRepository media;

  factory RepositoryBundle.local(LocalStore store) {
    final carts = LocalCartRepository(store);
    return RepositoryBundle(
      mode: BackendMode.local,
      auth: LocalAuthRepository(store),
      carts: carts,
      follows: LocalFollowRepository(store, carts),
      notifications: LocalNotificationRepository(store),
      moderation: LocalModerationRepository(store, carts),
      media: LocalMediaRepository(),
    );
  }

  /// Only constructed after `Firebase.initializeApp` has succeeded, so no
  /// `FirebaseFirestore.instance` is touched in local mode. The deleted
  /// `FirebaseService` held these as eager static finals, which would have
  /// thrown `[core/no-app]` the moment anything imported it.
  factory RepositoryBundle.firebase() {
    final carts = FirestoreCartRepository();
    return RepositoryBundle(
      mode: BackendMode.firebase,
      auth: FirebaseAuthRepository(),
      carts: carts,
      follows: FirestoreFollowRepository(carts: carts),
      notifications: FirestoreNotificationRepository(),
      moderation: FirestoreModerationRepository(carts: carts),
      media: FirebaseMediaRepository(),
    );
  }

  void dispose() => auth.dispose();
}
