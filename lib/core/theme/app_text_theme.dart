import 'package:flutter/material.dart';

/// Font family for the whole app: Outfit, bundled in assets/fonts/outfit
/// (weights 400, 500, 600 and 700) and declared in pubspec.yaml. Outfit is free
/// under the SIL Open Font License (assets/fonts/outfit/OFL.txt). To change the
/// font, bundle another family and change this one name.
const String tickyFontFamily = 'Outfit';

/// Typography: round, friendly and a little oversized. Headlines are big and
/// bold with tight tracking, like "Start today's tasks." Body text is relaxed
/// and secondary text is muted. Hierarchy comes from size and weight.
TextTheme buildTextTheme(ColorScheme scheme) {
  final base = ThemeData(brightness: scheme.brightness, useMaterial3: true)
      .textTheme
      .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
        fontFamily: tickyFontFamily,
      );

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -1.6,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    // The page headline.
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.4,
      letterSpacing: 0,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14.5,
      height: 1.4,
      letterSpacing: 0,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 13,
      color: scheme.onSurfaceVariant,
      height: 1.35,
      letterSpacing: 0,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
  );
}
