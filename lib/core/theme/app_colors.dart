import 'package:flutter/painting.dart';

/// Ticky brand palette. The app is dark-only.
///
/// The five brand colours are fixed. Everything else is a neutral derived from
/// them, kept deliberately close together: structure comes from hairline
/// borders, not from boxes of different brightness.
abstract final class AppColors {
  // Brand
  static const deepBackground = Color(0xFF0B0912);
  static const premiumPurple = Color(0xFF8B5CF6);
  static const softViolet = Color(0xFFA78BFA);
  static const highlight = Color(0xFFC4B5FD);
  static const white = Color(0xFFF5F3FF);

  // Surfaces, from the page background up to raised elements. Steps are small.
  static const surfaceLowest = Color(0xFF08070D);
  static const surfaceLow = Color(0xFF0F0D16);
  static const surface = Color(0xFF131119);
  static const surfaceHigh = Color(0xFF191720);
  static const surfaceHighest = Color(0xFF211E2A);

  // Text and lines
  static const textMuted = Color(0xFFA29EB4);

  /// Stronger line: unchecked rings, outlined buttons, hover states.
  static const outline = Color(0xFF3F3A52);

  /// The hairline: card edges, dividers, input borders.
  static const outlineSoft = Color(0xFF26222F);

  // Containers: selected states. A faint purple tint, never a solid block.
  static const primaryContainer = Color(0xFF21183A);
  static const onPrimaryContainer = Color(0xFFEDE9FE);
  static const secondaryContainer = Color(0xFF1B1530);
  static const onSecondaryContainer = Color(0xFFDDD6FE);
  static const tertiaryContainer = Color(0xFF261D44);

  // Status. Not part of the brand palette, but the checklist needs them.
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const errorContainer = Color(0xFF3B1A20);
  static const onErrorContainer = Color(0xFFFECACA);
}
