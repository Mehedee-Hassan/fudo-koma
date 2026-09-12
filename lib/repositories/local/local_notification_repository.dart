import '../../core/id_generator.dart';
import '../../models/cart_update_model.dart';
import '../../models/notification_model.dart';
import '../notification_repository.dart';
import 'local_keys.dart';
import 'local_store.dart';

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._store);

  final LocalStore _store;

  /// Keeps the on-device feed bounded; SharedPreferences is not a database.
  static const int _maxPerUser = 100;

  List<NotificationModel> _decodeFor(
    Map<String, Map<String, dynamic>> docs,
    String userId,
  ) {
    final items = docs.entries
        .where((e) => e.value['userId'] == userId)
        .map((e) => NotificationModel.fromMap(e.value, e.key))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Stream<List<NotificationModel>> watchFeed(String userId) => _store
      .watchCollection(LocalKeys.notifications)
      .map((docs) => _decodeFor(docs, userId));

  @override
  Stream<int> watchUnreadCount(String userId) => watchFeed(userId)
      .map((items) => items.where((n) => !n.isRead).length)
      .distinct();

  @override
  Future<void> push(NotificationModel notification) =>
      pushAll(<NotificationModel>[notification]);

  @override
  Future<void> pushAll(List<NotificationModel> notifications) async {
    if (notifications.isEmpty) return;

    final docs = _store.readCollection(LocalKeys.notifications);
    for (final item in notifications) {
      final id = item.id.isEmpty ? newId('note') : item.id;
      docs[id] = item.toMap();
    }
    await _store.writeCollection(LocalKeys.notifications, _prune(docs));
  }

  @override
  Future<void> markRead(String notificationId) => _store.updateDoc(
        LocalKeys.notifications,
        // Callers address notifications as "userId/noteId" because Firestore
        // stores them in a per-user subcollection; locally only the id matters.
        notificationId.split('/').last,
        (current) => current..['isRead'] = true,
      );

  @override
  Future<void> markAllRead(String userId) async {
    final docs = _store.readCollection(LocalKeys.notifications);
    var changed = false;
    for (final entry in docs.entries) {
      if (entry.value['userId'] == userId && entry.value['isRead'] != true) {
        entry.value['isRead'] = true;
        changed = true;
      }
    }
    if (changed) {
      await _store.writeCollection(LocalKeys.notifications, docs);
    }
  }

  @override
  Future<void> recordCartUpdate(CartUpdateModel update) async {
    final id = update.id.isEmpty ? newId('update') : update.id;
    await _store.setDoc(LocalKeys.cartUpdates, id, update.toMap());
  }

  @override
  Stream<List<CartUpdateModel>> watchCartUpdates(String cartId) =>
      _store.watchCollection(LocalKeys.cartUpdates).map((docs) {
        final items = docs.entries
            .where((e) => e.value['cartId'] == cartId)
            .map((e) => CartUpdateModel.fromMap(e.value, e.key))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });

  Map<String, Map<String, dynamic>> _prune(
    Map<String, Map<String, dynamic>> docs,
  ) {
    final byUser = <String, List<MapEntry<String, Map<String, dynamic>>>>{};
    for (final entry in docs.entries) {
      byUser
          .putIfAbsent(entry.value['userId'] as String? ?? '', () => [])
          .add(entry);
    }

    final keep = <String, Map<String, dynamic>>{};
    for (final entries in byUser.values) {
      entries.sort((a, b) {
        final aAt = a.value['createdAt'] as String? ?? '';
        final bAt = b.value['createdAt'] as String? ?? '';
        return bAt.compareTo(aAt);
      });
      for (final entry in entries.take(_maxPerUser)) {
        keep[entry.key] = entry.value;
      }
    }
    return keep;
  }
}
