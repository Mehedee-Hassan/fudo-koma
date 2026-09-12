import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cart_update_model.dart';
import '../../models/notification_model.dart';
import '../notification_repository.dart';
import 'firestore_refs.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<List<NotificationModel>> watchFeed(String userId) =>
      FirestoreRefs.notifications(_db, userId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => NotificationModel.fromMap(d.data(), d.id))
              .toList());

  @override
  Stream<int> watchUnreadCount(String userId) =>
      FirestoreRefs.notifications(_db, userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snap) => snap.docs.length)
          .distinct();

  @override
  Future<void> push(NotificationModel notification) =>
      pushAll(<NotificationModel>[notification]);

  @override
  Future<void> pushAll(List<NotificationModel> notifications) async {
    if (notifications.isEmpty) return;

    // Firestore caps a batch at 500 writes; chunk so a popular cart's fan-out
    // does not fail wholesale.
    const chunkSize = 400;
    for (var start = 0; start < notifications.length; start += chunkSize) {
      final chunk = notifications.skip(start).take(chunkSize);
      final batch = _db.batch();
      for (final item in chunk) {
        final ref = FirestoreRefs.notifications(_db, item.userId)
            .doc(item.id.isEmpty ? null : item.id);
        batch.set(ref, item.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    // Subcollection writes need the owning user; callers pass "userId/noteId".
    final parts = notificationId.split('/');
    if (parts.length != 2) return;
    await FirestoreRefs.notifications(_db, parts.first)
        .doc(parts.last)
        .update(<String, dynamic>{'isRead': true});
  }

  @override
  Future<void> markAllRead(String userId) async {
    final snap = await FirestoreRefs.notifications(_db, userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, <String, dynamic>{'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> recordCartUpdate(CartUpdateModel update) =>
      FirestoreRefs.cartUpdates(_db, update.cartId)
          .doc(update.id.isEmpty ? null : update.id)
          .set(update.toMap());

  @override
  Stream<List<CartUpdateModel>> watchCartUpdates(String cartId) =>
      FirestoreRefs.cartUpdates(_db, cartId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => CartUpdateModel.fromMap(d.data(), d.id))
              .toList());
}
