import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';

@immutable
class FollowModel {
  const FollowModel({
    required this.id,
    required this.userId,
    required this.cartId,
    required this.followedAt,
    this.notificationsEnabled = true,
    this.proximityAlertKm = defaultRadiusKm,
  });

  /// Was 3, while the map circle, the proximity service and every piece of UI
  /// copy already used 5. A default must be a compile-time constant, so the
  /// assert below keeps it pinned to the single radius constant.
  static const int defaultRadiusKm = 5;

  final String id;
  final String userId;
  final String cartId;
  final DateTime followedAt;
  final bool notificationsEnabled;
  final int proximityAlertKm;

  /// Guards against `AppConstants.alertRadiusKm` and the const default drifting
  /// apart the way the old 3-vs-5 mismatch did.
  static bool get defaultMatchesAppRadius =>
      defaultRadiusKm == AppConstants.alertRadiusKm.round();

  /// Deterministic composite id, so follow/unfollow are idempotent
  /// set/delete operations needing no lookup query in either backend.
  static String idFor(String userId, String cartId) => '${userId}_$cartId';

  FollowModel copyWith({
    String? id,
    String? userId,
    String? cartId,
    DateTime? followedAt,
    bool? notificationsEnabled,
    int? proximityAlertKm,
  }) {
    return FollowModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cartId: cartId ?? this.cartId,
      followedAt: followedAt ?? this.followedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      proximityAlertKm: proximityAlertKm ?? this.proximityAlertKm,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'userId': userId,
        'cartId': cartId,
        'followedAt': followedAt.toIso8601String(),
        'notificationsEnabled': notificationsEnabled,
        'proximityAlertKm': proximityAlertKm,
      };

  factory FollowModel.fromMap(Map<String, dynamic> map, String id) {
    return FollowModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      cartId: map['cartId'] as String? ?? '',
      followedAt: DateTime.tryParse(map['followedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      // Fallback also had to move 3 -> 5; missing it would have silently kept
      // every already-persisted follow on the old radius.
      proximityAlertKm:
          (map['proximityAlertKm'] as num?)?.toInt() ?? defaultRadiusKm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowModel &&
          other.id == id &&
          other.userId == userId &&
          other.cartId == cartId &&
          other.followedAt == followedAt &&
          other.notificationsEnabled == notificationsEnabled &&
          other.proximityAlertKm == proximityAlertKm;

  @override
  int get hashCode => Object.hash(
      id, userId, cartId, followedAt, notificationsEnabled, proximityAlertKm);
}
