import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository);

  final NotificationRepository _repository;
  StreamSubscription<List<NotificationModel>>? _sub;

  String? _userId;
  List<NotificationModel> _feed = const <NotificationModel>[];

  List<NotificationModel> get feed => _feed;
  int get unreadCount => _feed.where((n) => !n.isRead).length;
  bool get isEmpty => _feed.isEmpty;

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _sub = null;

    if (userId == null) {
      _feed = const <NotificationModel>[];
      notifyListeners();
      return;
    }

    _sub = _repository.watchFeed(userId).listen((feed) {
      _feed = feed;
      notifyListeners();
    });
  }

  Future<void> markAllRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _repository.markAllRead(userId);
  }

  Future<void> markRead(NotificationModel notification) =>
      _repository.markRead(_addressOf(notification));

  /// Firestore keeps notifications in a per-user subcollection, so a write
  /// needs the owning uid alongside the document id.
  String _addressOf(NotificationModel notification) =>
      '${notification.userId}/${notification.id}';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
