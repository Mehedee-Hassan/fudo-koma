import 'package:flutter/foundation.dart';

enum CartUpdateType {
  opened,
  closed,
  moved,
  scheduleChanged,
  photoAdded,
  announcement;

  static CartUpdateType fromWire(String? value) =>
      CartUpdateType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => CartUpdateType.announcement,
      );

  String get wire => name;
}

/// A public entry in a cart's activity log.
///
/// Owner actions fan out on write: one `CartUpdateModel` on the cart's log,
/// plus one `NotificationModel` per follower inbox. The Updates tab then reads
/// a single stream with no client-side join - the same shape a Cloud Function
/// would produce server-side, so the local implementation is a faithful
/// rehearsal rather than throwaway work.
@immutable
class CartUpdateModel {
  const CartUpdateModel({
    required this.id,
    required this.cartId,
    required this.cartName,
    required this.ownerId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String cartId;
  final String cartName;
  final String ownerId;
  final CartUpdateType type;
  final String message;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cartId': cartId,
        'cartName': cartName,
        'ownerId': ownerId,
        'type': type.wire,
        'message': message,
        'locationLabel': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CartUpdateModel.fromMap(Map<String, dynamic> map, String id) {
    return CartUpdateModel(
      id: id,
      cartId: map['cartId'] as String? ?? '',
      cartName: map['cartName'] as String? ?? 'Food cart',
      ownerId: map['ownerId'] as String? ?? '',
      type: CartUpdateType.fromWire(map['type'] as String?),
      message: map['message'] as String? ?? '',
      locationLabel: map['locationLabel'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CartUpdateModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
