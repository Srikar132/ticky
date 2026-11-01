import 'package:flutter/material.dart';

/// Font family for the whole app: Inter, bundled in assets/fonts/inter
/// (weights 400, 500, 600 and 700) and declared in pubspec.yaml. Inter is free
/// under the SIL Open Font License (assets/fonts/inter/OFL.txt). To change the
/// font, bundle another family and change this one name.
const String tickyFontFamily = 'Inter';

/// Typography for the dark theme: calm and tight, like a tool rather than a
/// poster. Headings are semibold with slightly negative tracking, body text is
/// small with relaxed line height, and secondary text is muted. Hierarchy
/// comes from size, weight and colour, never from decoration.
TextTheme buildTextTheme(ColorScheme scheme) {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true)
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
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 12.5,
      color: scheme.onSurfaceVariant,
      height: 1.4,
      letterSpacing: 0,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
  );
}
