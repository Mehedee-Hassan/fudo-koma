import 'package:flutter/material.dart';

/// The hex values that were previously scattered as literals through
/// `main.dart`. Defined once so a palette change is a one-file edit.
abstract final class AppColors {
  static const Color primary = Color(0xFF176B5B);
  static const Color secondary = Color(0xFFE66D45);
  static const Color background = Color(0xFFF7F8F4);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE3E7E1);
  static const Color primarySoft = Color(0xFFD9EEE6);
  static const Color secondarySoft = Color(0xFFFFE8DE);
  static const Color ink = Color(0xFF24342F);
  static const Color open = Color(0xFF4AAE7D);
  static const Color closed = Color(0xFF8A938F);
  static const Color warning = Color(0xFFE1A43A);
  static const Color danger = Color(0xFFC0453B);

  static const Color radiusFill = Color(0x26176B5B);
  static const Color radiusStroke = Color(0x88176B5B);
}
