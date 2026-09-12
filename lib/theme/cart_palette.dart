import 'package:flutter/material.dart';

/// Replaces the `color` field that used to live on the inline `FoodCart` model.
///
/// Colour is presentation, not data: storing it meant every backend had to
/// round-trip an ARGB int, and a cart created through Firestore had no colour
/// at all. Deriving it keeps the model portable and the visuals identical.
abstract final class CartPalette {
  static const List<Color> _palette = <Color>[
    Color(0xFFE66D45),
    Color(0xFF3C8B70),
    Color(0xFFE1A43A),
    Color(0xFFB95D3B),
    Color(0xFF8D6E3E),
    Color(0xFF5D7891),
    Color(0xFFC65B7A),
    Color(0xFF6B7F3C),
  ];

  static const Map<String, Color> _byKeyword = <String, Color>{
    'tea': Color(0xFFE1A43A),
    'coffee': Color(0xFFE1A43A),
    'chai': Color(0xFFE1A43A),
    'salad': Color(0xFF3C8B70),
    'bowl': Color(0xFF3C8B70),
    'vegan': Color(0xFF3C8B70),
    'taco': Color(0xFFB95D3B),
    'mexican': Color(0xFFB95D3B),
    'dosa': Color(0xFF8D6E3E),
    'indian': Color(0xFF8D6E3E),
    'noodle': Color(0xFF5D7891),
    'ramen': Color(0xFF5D7891),
    'dumpling': Color(0xFF5D7891),
    'dessert': Color(0xFFC65B7A),
    'waffle': Color(0xFFC65B7A),
    'crepe': Color(0xFFC65B7A),
    'shake': Color(0xFFC65B7A),
    'momo': Color(0xFFE66D45),
    'nepali': Color(0xFFE66D45),
  };

  static Color colorFor({required String id, String? category}) {
    if (category != null) {
      final haystack = category.toLowerCase();
      for (final entry in _byKeyword.entries) {
        if (haystack.contains(entry.key)) return entry.value;
      }
    }
    return _palette[_stableHash(id) % _palette.length];
  }

  /// FNV-1a rather than `String.hashCode`.
  ///
  /// Dart's string hash is seeded per isolate and is not guaranteed stable
  /// across platforms or SDK versions, so the same cart would render in a
  /// different colour on web than on Android - a real and very confusing bug.
  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
