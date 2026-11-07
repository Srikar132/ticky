import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_colors.dart';

/// Colours that Material's [ColorScheme] has no slot for.
///
/// Read with `context.tickyColors`.
@immutable
class TickyColors extends ThemeExtension<TickyColors> {
  const TickyColors({
    required this.success,
    required this.warning,
    required this.coin,
    required this.streak,
    required this.highlight,
    required this.tileLavender,
    required this.tileBlue,
    required this.tilePink,
    required this.tileMint,
    required this.tileButter,
    required this.tilePeach,
  });

  /// Completed tasks and positive progress.
  final Color success;

  /// Overdue or reminding states.
  final Color warning;

  /// Coin balance.
  final Color coin;

  /// Streak flame.
  final Color streak;

  /// Soft accent for selected states.
  final Color highlight;

  /// Big soft pastel blocks. Text on them uses the normal text colour.
  final Color tileLavender;
  final Color tileBlue;
  final Color tilePink;
  final Color tileMint;
  final Color tileButter;
  final Color tilePeach;

  static const light = TickyColors(
    success: AppColors.success,
    warning: AppColors.warning,
    coin: Color(0xFFD99A00),
    streak: Color(0xFFE8631A),
    highlight: AppColors.highlight,
    tileLavender: AppColors.tileLavender,
    tileBlue: AppColors.tileBlue,
    tilePink: AppColors.tilePink,
    tileMint: AppColors.tileMint,
    tileButter: AppColors.tileButter,
    tilePeach: AppColors.tilePeach,
  );

  static const dark = TickyColors(
    success: AppDarkColors.success,
    warning: AppDarkColors.warning,
    coin: Color(0xFFFFD166),
    streak: Color(0xFFFB923C),
    highlight: Color(0xFFC4B5FD),
    tileLavender: AppDarkColors.tileLavender,
    tileBlue: AppDarkColors.tileBlue,
    tilePink: AppDarkColors.tilePink,
    tileMint: AppDarkColors.tileMint,
    tileButter: AppDarkColors.tileButter,
    tilePeach: AppDarkColors.tilePeach,
  );

  @override
  TickyColors copyWith({
    Color? success,
    Color? warning,
    Color? coin,
    Color? streak,
    Color? highlight,
    Color? tileLavender,
    Color? tileBlue,
    Color? tilePink,
    Color? tileMint,
    Color? tileButter,
    Color? tilePeach,
  }) {
    return TickyColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      coin: coin ?? this.coin,
      streak: streak ?? this.streak,
      highlight: highlight ?? this.highlight,
      tileLavender: tileLavender ?? this.tileLavender,
      tileBlue: tileBlue ?? this.tileBlue,
      tilePink: tilePink ?? this.tilePink,
      tileMint: tileMint ?? this.tileMint,
      tileButter: tileButter ?? this.tileButter,
      tilePeach: tilePeach ?? this.tilePeach,
    );
  }

  @override
  TickyColors lerp(ThemeExtension<TickyColors>? other, double t) {
    if (other is! TickyColors) return this;
    return TickyColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      coin: Color.lerp(coin, other.coin, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      tileLavender: Color.lerp(tileLavender, other.tileLavender, t)!,
      tileBlue: Color.lerp(tileBlue, other.tileBlue, t)!,
      tilePink: Color.lerp(tilePink, other.tilePink, t)!,
      tileMint: Color.lerp(tileMint, other.tileMint, t)!,
      tileButter: Color.lerp(tileButter, other.tileButter, t)!,
      tilePeach: Color.lerp(tilePeach, other.tilePeach, t)!,
    );
  }
}

extension TickyThemeContext on BuildContext {
  TickyColors get tickyColors => Theme.of(this).extension<TickyColors>()!;
}
