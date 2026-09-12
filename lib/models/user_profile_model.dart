import 'package:flutter/foundation.dart';

import 'user_role.dart';

@immutable
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.name,
    required this.createdAt,
    this.email = '',
    this.role = UserRole.customer,
    this.isGuest = false,
    this.isBlocked = false,
    this.photoRef,
    this.fcmToken,
    this.ownedCartId,
    this.blockedAt,
    this.blockedBy,
    this.blockedReason,
    this.proximityAlertsEnabled = true,
    this.lastSeenAt,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool isGuest;
  final bool isBlocked;
  final String? photoRef;
  final String? fcmToken;
  final String? ownedCartId;
  final DateTime? blockedAt;
  final String? blockedBy;
  final String? blockedReason;
  final bool proximityAlertsEnabled;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  bool get isOwner => role == UserRole.owner;
  bool get isAdmin => role == UserRole.admin;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? isGuest,
    bool? isBlocked,
    String? photoRef,
    String? fcmToken,
    bool clearFcmToken = false,
    String? ownedCartId,
    bool clearOwnedCartId = false,
    DateTime? blockedAt,
    String? blockedBy,
    String? blockedReason,
    bool clearBlockDetails = false,
    bool? proximityAlertsEnabled,
    DateTime? lastSeenAt,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isGuest: isGuest ?? this.isGuest,
      isBlocked: isBlocked ?? this.isBlocked,
      photoRef: photoRef ?? this.photoRef,
      fcmToken: clearFcmToken ? null : (fcmToken ?? this.fcmToken),
      ownedCartId:
          clearOwnedCartId ? null : (ownedCartId ?? this.ownedCartId),
      blockedAt: clearBlockDetails ? null : (blockedAt ?? this.blockedAt),
      blockedBy: clearBlockDetails ? null : (blockedBy ?? this.blockedBy),
      blockedReason:
          clearBlockDetails ? null : (blockedReason ?? this.blockedReason),
      proximityAlertsEnabled:
          proximityAlertsEnabled ?? this.proximityAlertsEnabled,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'email': email,
        'role': role.wire,
        'isGuest': isGuest,
        'isBlocked': isBlocked,
        'photoRef': photoRef,
        'fcmToken': fcmToken,
        'ownedCartId': ownedCartId,
        'blockedAt': blockedAt?.toIso8601String(),
        'blockedBy': blockedBy,
        'blockedReason': blockedReason,
        'proximityAlertsEnabled': proximityAlertsEnabled,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String id) {
    return UserProfileModel(
      id: id,
      name: map['name'] as String? ?? 'Follo Cart user',
      email: map['email'] as String? ?? '',
      role: UserRole.fromWire(map['role'] as String?),
      isGuest: map['isGuest'] as bool? ?? false,
      isBlocked: map['isBlocked'] as bool? ?? false,
      photoRef: map['photoRef'] as String?,
      fcmToken: map['fcmToken'] as String?,
      ownedCartId: map['ownedCartId'] as String?,
      blockedAt: map['blockedAt'] == null
          ? null
          : DateTime.tryParse(map['blockedAt'] as String),
      blockedBy: map['blockedBy'] as String?,
      blockedReason: map['blockedReason'] as String?,
      proximityAlertsEnabled: map['proximityAlertsEnabled'] as bool? ?? true,
      lastSeenAt: map['lastSeenAt'] == null
          ? null
          : DateTime.tryParse(map['lastSeenAt'] as String),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileModel &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.role == role &&
          other.isGuest == isGuest &&
          other.isBlocked == isBlocked &&
          other.photoRef == photoRef &&
          other.fcmToken == fcmToken &&
          other.ownedCartId == ownedCartId &&
          other.blockedAt == blockedAt &&
          other.blockedBy == blockedBy &&
          other.blockedReason == blockedReason &&
          other.proximityAlertsEnabled == proximityAlertsEnabled &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, email, role, isGuest, isBlocked,
      photoRef, fcmToken, ownedCartId, blockedAt, blockedBy, blockedReason,
      proximityAlertsEnabled, createdAt);
}
