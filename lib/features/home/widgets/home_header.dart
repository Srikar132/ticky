import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/home/models/day_phase.dart';
import 'package:ticky/features/home/widgets/stat_chip.dart';
import 'package:ticky/features/routine/models/streak.dart';

/// The top of Home: greeting and date on the left, streak and coins on the
/// right as white pills. The big headline sits underneath.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.now,
    required this.streak,
    required this.coins,
    required this.headline,
    required this.onStreakTap,
    required this.onCoinsTap,
  });

  final DateTime now;
  final StreakInfo streak;
  final int coins;

  /// The large page title, for example "Start today's tasks."
  final String headline;
  final VoidCallback onStreakTap;
  final VoidCallback onCoinsTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.tickyColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 4,
        AppSpacing.sm,
        AppSpacing.lg + 4,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greetingFor(now), style: text.titleMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            formatLongDate(now),
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatChip(
                icon: Icons.local_fire_department_rounded,
                color: colors.streak,
                value: streak.count,
                label: 'Day streak',
                dimmed: streak.count == 0,
                onTap: onStreakTap,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatChip(
                icon: Icons.monetization_on_rounded,
                color: colors.coin,
                value: coins,
                label: 'Coins',
                onTap: onCoinsTap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedSwitcher(
            duration: AppMotion.medium,
            child: Text(
              headline,
              key: ValueKey(headline),
              style: text.headlineLarge,
            ),
          ),
        ],
      ),
    );
  }
}
