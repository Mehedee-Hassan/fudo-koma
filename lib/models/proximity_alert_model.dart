import 'package:flutter/foundation.dart';

@immutable
class ProximityAlertModel {
  const ProximityAlertModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.cartName,
    required this.distanceKm,
    required this.triggeredAt,
    this.isDelivered = false,
  });

  final String id;
  final String userId;
  final String cartId;
  final String cartName;
  final double distanceKm;
  final DateTime triggeredAt;
  final bool isDelivered;

  ProximityAlertModel copyWith({
    String? id,
    String? userId,
    String? cartId,
    String? cartName,
    double? distanceKm,
    DateTime? triggeredAt,
    bool? isDelivered,
  }) {
    return ProximityAlertModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cartId: cartId ?? this.cartId,
      cartName: cartName ?? this.cartName,
      distanceKm: distanceKm ?? this.distanceKm,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      isDelivered: isDelivered ?? this.isDelivered,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'cartId': cartId,
        'cartName': cartName,
        'distanceKm': distanceKm,
        'triggeredAt': triggeredAt.toIso8601String(),
        'isDelivered': isDelivered,
      };

  factory ProximityAlertModel.fromMap(Map<String, dynamic> map, String id) {
    return ProximityAlertModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      cartId: map['cartId'] as String? ?? '',
      cartName: map['cartName'] as String? ?? 'Food cart',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      triggeredAt: DateTime.tryParse(map['triggeredAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isDelivered: map['isDelivered'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProximityAlertModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
