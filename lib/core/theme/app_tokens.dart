import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing scale. Use these instead of ad-hoc numbers.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Default horizontal padding of a screen.
  static const screen = EdgeInsets.symmetric(horizontal: lg);
}

/// Corner radii. Tight and consistent: panels and controls share [md].
abstract final class AppRadius {
  /// The small corner of a speech bubble.
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Line widths. Structure is drawn with a hairline, not with fills.
abstract final class AppStroke {
  /// Card edges, dividers, input borders.
  static const hairline = 1.0;

  /// A focused input, a selected control.
  static const focus = 1.5;
}

/// Control heights.
abstract final class AppSizes {
  /// Buttons in sheets and forms.
  static const control = 48.0;

  /// Buttons that sit in a row with others.
  static const compactControl = 44.0;
}

/// Animation timing, so motion feels consistent across screens.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;
}
