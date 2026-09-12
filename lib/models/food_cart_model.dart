import 'package:flutter/foundation.dart';

import '../core/formatters.dart';
import 'schedule_entry_model.dart';

/// The single cart model for the whole app.
///
/// The prototype carried a second, incompatible `FoodCart` class inside
/// `main.dart` with presentation-only fields (a `Color`, a hardcoded
/// `'0.8 km away'` string, a painter `Offset`). Those are derived at render
/// time now: colour from `CartPalette`, distance from the user's real position.
@immutable
class FoodCartModel {
  const FoodCartModel({
    required this.id,
    required this.name,
    required this.category,
    required this.locationLabel,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.description = '',
    this.photoRefs = const <String>[],
    this.scheduleEntries = const <ScheduleEntry>[],
    this.isOpen = false,
    this.isFeatured = false,
    this.isActive = true,
    this.followersCount = 0,
    this.lastLocationAt,
  });

  final String id;
  final String name;
  final String category;
  final String locationLabel;
  final String ownerId;
  final String description;

  /// Opaque references resolved by `MediaRepository.imageFor`: a relative file
  /// path in local mode, a download URL in Firebase mode, a `data:` URI on web.
  final List<String> photoRefs;

  final List<ScheduleEntry> scheduleEntries;

  final bool isOpen;
  final bool isFeatured;

  /// False when an admin has hidden the cart, or its owner has been blocked.
  final bool isActive;

  final double latitude;
  final double longitude;
  final DateTime? lastLocationAt;

  final int followersCount;
  final DateTime updatedAt;

  // NOTE: there is deliberately no `isFollowed` field. Follow state is
  // per-user and lives in FollowRepository. Caching it on a shared cart object
  // is how two signed-in users end up seeing each other's follows.

  String? get primaryPhotoRef =>
      photoRefs.isEmpty ? null : photoRefs.first;

  bool get hasPhotos => photoRefs.isNotEmpty;

  ScheduleEntry? scheduleForNow([DateTime? now]) {
    final reference = now ?? DateTime.now();
    for (final entry in scheduleEntries) {
      if (entry.coversNow(reference)) return entry;
    }
    return null;
  }

  /// Today's window, or the next one this week.
  String scheduleSummary([DateTime? now]) {
    final reference = now ?? DateTime.now();
    if (scheduleEntries.isEmpty) return 'No schedule published yet';

    final current = scheduleForNow(reference);
    if (current != null) {
      return 'Open until ${TimeOfDayFormat.fromMinutes(current.closeMinute)}';
    }

    final today = scheduleEntries
        .where((e) => e.isActive && !e.isOneOff && e.weekday == reference.weekday)
        .toList();
    final minuteOfDay = reference.hour * 60 + reference.minute;
    for (final entry in today) {
      if (entry.openMinute > minuteOfDay) {
        return 'Opens at ${TimeOfDayFormat.fromMinutes(entry.openMinute)}';
      }
    }

    for (var offset = 1; offset <= 7; offset++) {
      final weekday = ((reference.weekday - 1 + offset) % 7) + 1;
      final next = scheduleEntries
          .where((e) => e.isActive && !e.isOneOff && e.weekday == weekday)
          .toList();
      if (next.isNotEmpty) {
        final day = _weekdayLabel(weekday);
        return '$day ${TimeOfDayFormat.fromMinutes(next.first.openMinute)}';
      }
    }
    return 'Closed today';
  }

  ScheduleEntry? get nextStop {
    final upcoming = scheduleEntries
        .where((e) => e.isOneOff && e.isActive && e.specificDate != null)
        .toList()
      ..sort((a, b) => a.specificDate!.compareTo(b.specificDate!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  static String _weekdayLabel(int weekday) => const <int, String>{
        DateTime.monday: 'Monday',
        DateTime.tuesday: 'Tuesday',
        DateTime.wednesday: 'Wednesday',
        DateTime.thursday: 'Thursday',
        DateTime.friday: 'Friday',
        DateTime.saturday: 'Saturday',
        DateTime.sunday: 'Sunday',
      }[weekday] ??
      'Monday';

  FoodCartModel copyWith({
    String? id,
    String? name,
    String? category,
    String? locationLabel,
    String? ownerId,
    String? description,
    List<String>? photoRefs,
    List<ScheduleEntry>? scheduleEntries,
    bool? isOpen,
    bool? isFeatured,
    bool? isActive,
    double? latitude,
    double? longitude,
    DateTime? lastLocationAt,
    int? followersCount,
    DateTime? updatedAt,
  }) {
    return FoodCartModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      locationLabel: locationLabel ?? this.locationLabel,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      photoRefs: photoRefs ?? this.photoRefs,
      scheduleEntries: scheduleEntries ?? this.scheduleEntries,
      isOpen: isOpen ?? this.isOpen,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      followersCount: followersCount ?? this.followersCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Portable primitives only: ISO-8601 strings for dates, plain doubles for
  /// coordinates. Local mode wraps this in `jsonEncode`; Firestore writes the
  /// map directly. One codec, two backends.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'category': category,
        'locationLabel': locationLabel,
        'ownerId': ownerId,
        'description': description,
        'photoRefs': photoRefs,
        'scheduleEntries': scheduleEntries.map((e) => e.toMap()).toList(),
        'isOpen': isOpen,
        'isFeatured': isFeatured,
        'isActive': isActive,
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationAt': lastLocationAt?.toIso8601String(),
        'followersCount': followersCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FoodCartModel.fromMap(Map<String, dynamic> map, String id) {
    return FoodCartModel(
      id: id,
      name: map['name'] as String? ?? 'Food cart',
      category: map['category'] as String? ?? 'Street food',
      locationLabel: map['locationLabel'] as String? ?? 'Nearby',
      ownerId: map['ownerId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      photoRefs: (map['photoRefs'] as List?)?.cast<String>() ?? const <String>[],
      scheduleEntries: (map['scheduleEntries'] as List?)
              ?.map((e) => ScheduleEntry.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <ScheduleEntry>[],
      isOpen: map['isOpen'] as bool? ?? false,
      isFeatured: map['isFeatured'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      lastLocationAt: map['lastLocationAt'] == null
          ? null
          : DateTime.tryParse(map['lastLocationAt'] as String),
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodCartModel &&
          other.id == id &&
          other.name == name &&
          other.category == category &&
          other.locationLabel == locationLabel &&
          other.ownerId == ownerId &&
          other.description == description &&
          listEquals(other.photoRefs, photoRefs) &&
          listEquals(other.scheduleEntries, scheduleEntries) &&
          other.isOpen == isOpen &&
          other.isFeatured == isFeatured &&
          other.isActive == isActive &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.lastLocationAt == lastLocationAt &&
          other.followersCount == followersCount &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        locationLabel,
        ownerId,
        description,
        Object.hashAll(photoRefs),
        Object.hashAll(scheduleEntries),
        isOpen,
        isFeatured,
        isActive,
        latitude,
        longitude,
        lastLocationAt,
        followersCount,
        updatedAt,
      );
}
