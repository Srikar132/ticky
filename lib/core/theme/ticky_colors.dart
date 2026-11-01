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
  });

  /// Completed tasks and positive progress.
  final Color success;

  /// Overdue or reminding states.
  final Color warning;

  /// Coin balance.
  final Color coin;

  /// Streak flame.
  final Color streak;

  /// Soft accent for glows and selected states.
  final Color highlight;

  static const dark = TickyColors(
    success: AppColors.success,
    warning: AppColors.warning,
    coin: Color(0xFFFFD166),
    streak: Color(0xFFFB923C),
    highlight: AppColors.highlight,
  );

  @override
  TickyColors copyWith({
    Color? success,
    Color? warning,
    Color? coin,
    Color? streak,
    Color? highlight,
  }) {
    return TickyColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      coin: coin ?? this.coin,
      streak: streak ?? this.streak,
      highlight: highlight ?? this.highlight,
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
    );
  }
}

extension TickyThemeContext on BuildContext {
  TickyColors get tickyColors => Theme.of(this).extension<TickyColors>()!;
}
