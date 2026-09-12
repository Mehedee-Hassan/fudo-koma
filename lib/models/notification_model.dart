import 'package:flutter/foundation.dart';

enum NotificationType {
  proximity,
  opened,
  closed,
  scheduleChanged,
  moved,
  announcement,
  system;

  /// Unknown values fall back to `system` rather than throwing, so a document
  /// written by a newer client version cannot break an older one.
  static NotificationType fromWire(String? value) =>
      NotificationType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => NotificationType.system,
      );

  String get wire => name;
}

@immutable
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.message,
    required this.createdAt,
    this.type = NotificationType.system,
    this.cartName = '',
    this.distanceKm,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String cartId;
  final String cartName;
  final NotificationType type;
  final String message;
  final double? distanceKm;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? cartId,
    String? cartName,
    NotificationType? type,
    String? message,
    double? distanceKm,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cartId: cartId ?? this.cartId,
      cartName: cartName ?? this.cartName,
      type: type ?? this.type,
      message: message ?? this.message,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'cartId': cartId,
        'cartName': cartName,
        'type': type.wire,
        'message': message,
        'distanceKm': distanceKm,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      cartId: map['cartId'] as String? ?? '',
      cartName: map['cartName'] as String? ?? '',
      type: NotificationType.fromWire(map['type'] as String?),
      message: map['message'] as String? ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel && other.id == id && other.isRead == isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
