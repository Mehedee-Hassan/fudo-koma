import 'package:intl/intl.dart';

/// Renders a real, computed distance. The prototype showed hardcoded strings
/// like '0.8 km away' next to a real 5 km map circle that had no relationship
/// to them; these labels are derived from the user's actual position.
abstract final class DistanceFormat {
  static String label(double? km) {
    if (km == null) return 'Distance unavailable';
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  /// Bare magnitude, for sentences that supply their own suffix.
  static String short(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}

abstract final class RelativeTime {
  static String label(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);

    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(time);
    return DateFormat('d MMM').format(time);
  }
}

abstract final class TimeOfDayFormat {
  /// Minutes since midnight -> '11:30 AM'.
  static String fromMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  static String range(int openMinute, int closeMinute) =>
      '${fromMinutes(openMinute)} – ${fromMinutes(closeMinute)}';
}
