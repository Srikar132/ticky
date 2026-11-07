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
  static const screen = EdgeInsets.symmetric(horizontal: lg + 4);
}

/// Corner radii. Soft and round: tiles and cards use [lg], controls [md].
abstract final class AppRadius {
  /// The small corner of a speech bubble.
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
}

/// Line widths. Used sparingly: soft fills do most of the grouping.
abstract final class AppStroke {
  /// Dividers, input borders.
  static const hairline = 1.0;

  /// A focused input, a selected control.
  static const focus = 1.5;
}

/// Control heights.
abstract final class AppSizes {
  /// Buttons in sheets and forms.
  static const control = 54.0;

  /// Buttons that sit in a row with others.
  static const compactControl = 46.0;

  /// The round white icon buttons in page headers.
  static const roundButton = 46.0;
}

/// Animation timing, so motion feels consistent across screens.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;
}
