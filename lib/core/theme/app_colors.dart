import 'package:flutter/painting.dart';

/// Ticky palette: soft lavender and white, with pastel tiles for colour.
///
/// The app is light-only. The page is a very pale lavender, content sits on
/// white, and colour comes from large pastel tiles (see the `tile*` values).
/// Near-black [ink] carries the strong moments: headlines, the primary
/// button, the selected pill. Purple is a quiet accent for focus and switches.
abstract final class AppColors {
  // Brand
  static const premiumPurple = Color(0xFF7456E8);
  static const softViolet = Color(0xFF9B83F2);
  static const highlight = Color(0xFFC9B8FA);

  /// Near-black used for headlines, primary buttons and selected pills.
  static const ink = Color(0xFF16131F);

  // Surfaces. The page is lavender, content is white, fills are lavender tints.
  static const canvas = Color(0xFFF6F3FF);
  static const white = Color(0xFFFFFFFF);
  static const fill = Color(0xFFEFEAFC);
  static const fillStrong = Color(0xFFE5DEF8);

  // Text and lines
  static const textMuted = Color(0xFF645F7C);

  /// Stronger line: unchecked rings, outlined buttons.
  static const outline = Color(0xFFC9C1E0);

  /// The hairline: dividers, input borders.
  static const outlineSoft = Color(0xFFE6E0F5);

  // Containers: selected states, a lavender tint.
  static const primaryContainer = Color(0xFFE6DDFB);
  static const onPrimaryContainer = Color(0xFF2B1D63);
  static const secondaryContainer = Color(0xFFEDE7FC);
  static const onSecondaryContainer = Color(0xFF2B1D63);
  static const tertiaryContainer = Color(0xFFDCD0F8);

  // Pastel tiles. Big soft blocks with dark text on top.
  static const tileLavender = Color(0xFFE3D8FB);
  static const tileBlue = Color(0xFFDCEAFB);
  static const tilePink = Color(0xFFF7DEEB);
  static const tileMint = Color(0xFFD6F0E5);
  static const tileButter = Color(0xFFF8EBCB);
  static const tilePeach = Color(0xFFFBE2D3);

  // Status. Deep enough to read as text on white.
  static const success = Color(0xFF1F9D6F);
  static const warning = Color(0xFFB86E00);
  static const error = Color(0xFFBA2F48);
  static const errorContainer = Color(0xFFFBE3E7);
  static const onErrorContainer = Color(0xFF7A1424);
}

/// The dark counterpart: a deep violet-black page, slightly lifted cards, and
/// the same pastel tiles pulled down to deep, muted tones. Text on the tiles
/// stays light.
abstract final class AppDarkColors {
  static const premiumPurple = Color(0xFF9B83F2);
  static const onPrimary = Color(0xFF15101F);

  static const canvas = Color(0xFF110F18);
  static const card = Color(0xFF1B1824);
  static const fill = Color(0xFF252133);
  static const fillStrong = Color(0xFF302B42);

  /// Text, and the "ink" pill colour (inverse of the page).
  static const text = Color(0xFFF4F1FF);
  static const textMuted = Color(0xFFA8A3BE);

  static const outline = Color(0xFF4B4663);
  static const outlineSoft = Color(0xFF2B2739);

  static const primaryContainer = Color(0xFF362B63);
  static const onPrimaryContainer = Color(0xFFEDE7FE);
  static const secondaryContainer = Color(0xFF2A2342);
  static const tertiaryContainer = Color(0xFF3F3370);

  static const tileLavender = Color(0xFF3A3066);
  static const tileBlue = Color(0xFF263B5E);
  static const tilePink = Color(0xFF5B2F49);
  static const tileMint = Color(0xFF1F4B3F);
  static const tileButter = Color(0xFF574823);
  static const tilePeach = Color(0xFF5B3B2B);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
  static const errorContainer = Color(0xFF3B1A20);
  static const onErrorContainer = Color(0xFFFECACA);
}
