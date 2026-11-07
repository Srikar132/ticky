import 'package:flutter/material.dart' show Brightness;
import 'package:flutter/painting.dart';
import 'package:ticky/core/theme/app_colors.dart';

/// Soft background and readable foreground derived from one accent colour,
/// such as a category colour. Keeps user-picked colours consistent with the
/// pastel look of the app in both light and dark.
extension ColorTones on Color {
  /// A wash of this colour over the card colour, for chip backgrounds.
  Color soft(Brightness brightness) => brightness == Brightness.light
      ? Color.alphaBlend(withValues(alpha: 0.2), AppColors.white)
      : Color.alphaBlend(withValues(alpha: 0.26), AppDarkColors.card);

  /// This colour pushed dark (light mode) or light (dark mode), so it reads as
  /// text on [soft].
  Color deep(Brightness brightness) {
    final hsl = HSLColor.fromColor(this);
    if (brightness == Brightness.light) {
      return hsl
          .withLightness(hsl.lightness.clamp(0.0, 0.34))
          .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
          .toColor();
    }
    return hsl.withLightness(hsl.lightness.clamp(0.74, 1.0)).toColor();
  }
}
