import '../core/formatters.dart';

/// One serving window. Replaces the free-text `schedule` string, which could
/// not be queried, compared against the clock, or edited in a structured way.
class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.weekday,
    required this.openMinute,
    required this.closeMinute,
    this.locationLabel = '',
    this.latitude,
    this.longitude,
    this.specificDate,
    this.isActive = true,
  });

  final String id;

  /// `DateTime.monday` .. `DateTime.sunday`.
  final int weekday;

  /// Minutes since midnight.
  final int openMinute;
  final int closeMinute;

  final String locationLabel;
  final double? latitude;
  final double? longitude;

  /// Non-null marks a one-off "next stop" rather than a weekly recurrence.
  final DateTime? specificDate;

  final bool isActive;

  bool get isOneOff => specificDate != null;
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Handles windows that run past midnight (a 10 PM - 1 AM cart is open at
  /// 12:30 AM), which a naive `open <= now && now <= close` comparison misses.
  bool coversNow(DateTime now) {
    if (!isActive) return false;

    if (specificDate case final date?) {
      if (date.year != now.year || date.month != now.month || date.day != now.day) {
        return false;
      }
    } else if (weekday != now.weekday) {
      return false;
    }

    final minuteOfDay = now.hour * 60 + now.minute;
    if (closeMinute >= openMinute) {
      return minuteOfDay >= openMinute && minuteOfDay <= closeMinute;
    }
    return minuteOfDay >= openMinute || minuteOfDay <= closeMinute;
  }

  String timeLabel() => TimeOfDayFormat.range(openMinute, closeMinute);

  ScheduleEntry copyWith({
    String? id,
    int? weekday,
    int? openMinute,
    int? closeMinute,
    String? locationLabel,
    double? latitude,
    double? longitude,
    DateTime? specificDate,
    bool clearSpecificDate = false,
    bool? isActive,
  }) {
    return ScheduleEntry(
      id: id ?? this.id,
      weekday: weekday ?? this.weekday,
      openMinute: openMinute ?? this.openMinute,
      closeMinute: closeMinute ?? this.closeMinute,
      locationLabel: locationLabel ?? this.locationLabel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      specificDate:
          clearSpecificDate ? null : (specificDate ?? this.specificDate),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'weekday': weekday,
        'openMinute': openMinute,
        'closeMinute': closeMinute,
        'locationLabel': locationLabel,
        'latitude': latitude,
        'longitude': longitude,
        'specificDate': specificDate?.toIso8601String(),
        'isActive': isActive,
      };

  factory ScheduleEntry.fromMap(Map<String, dynamic> map) {
    return ScheduleEntry(
      id: map['id'] as String? ?? '',
      weekday: (map['weekday'] as num?)?.toInt() ?? DateTime.monday,
      openMinute: (map['openMinute'] as num?)?.toInt() ?? 11 * 60,
      closeMinute: (map['closeMinute'] as num?)?.toInt() ?? 21 * 60,
      locationLabel: map['locationLabel'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      specificDate: map['specificDate'] == null
          ? null
          : DateTime.tryParse(map['specificDate'] as String),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleEntry &&
          other.id == id &&
          other.weekday == weekday &&
          other.openMinute == openMinute &&
          other.closeMinute == closeMinute &&
          other.locationLabel == locationLabel &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.specificDate == specificDate &&
          other.isActive == isActive;

  @override
  int get hashCode => Object.hash(id, weekday, openMinute, closeMinute,
      locationLabel, latitude, longitude, specificDate, isActive);
}
