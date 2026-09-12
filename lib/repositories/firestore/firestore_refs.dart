import 'package:cloud_firestore/cloud_firestore.dart';

/// Collection layout.
///
/// Two deliberate shape choices:
/// - `follows` uses a deterministic composite id (`{userId}_{cartId}`), so
///   follow and unfollow are idempotent set/delete calls with no query.
/// - notifications live in a per-user subcollection rather than a root
///   collection with a `userId` field: no composite index is needed and the
///   security rule is a one-liner.
abstract final class FirestoreRefs {
  static CollectionReference<Map<String, dynamic>> users(FirebaseFirestore db) =>
      db.collection('users');

  static CollectionReference<Map<String, dynamic>> carts(FirebaseFirestore db) =>
      db.collection('carts');

  static CollectionReference<Map<String, dynamic>> follows(
          FirebaseFirestore db) =>
      db.collection('follows');

  static CollectionReference<Map<String, dynamic>> reports(
          FirebaseFirestore db) =>
      db.collection('reports');

  static CollectionReference<Map<String, dynamic>> notifications(
    FirebaseFirestore db,
    String userId,
  ) =>
      db.collection('users').doc(userId).collection('notifications');

  static CollectionReference<Map<String, dynamic>> cartUpdates(
    FirebaseFirestore db,
    String cartId,
  ) =>
      db.collection('carts').doc(cartId).collection('updates');
}
