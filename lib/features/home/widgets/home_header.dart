import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/home/models/day_phase.dart';
import 'package:ticky/features/home/widgets/stat_chip.dart';
import 'package:ticky/features/routine/models/streak.dart';

/// The Home app bar. Expanded it shows the time-of-day artwork, the greeting,
/// and Ticky at the bottom left. Collapsed it shrinks to a bar that keeps the
/// streak, coins and settings within reach.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.now,
    required this.streak,
    required this.coins,
    required this.mood,
    this.idlePose,
    required this.message,
    required this.onMascotTap,
    required this.onStreakTap,
    required this.onCoinsTap,
    required this.onSettingsTap,
  });

  static const expandedHeight = 316.0;

  final DateTime now;
  final StreakInfo streak;
  final int coins;
  final MascotMood mood;

  /// The pose from the item shop that Ticky wears while idle, or null.
  final String? idlePose;
  final String message;
  final VoidCallback onMascotTap;
  final VoidCallback onStreakTap;
  final VoidCallback onCoinsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.tickyColors;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      backgroundColor: scheme.surface,
      automaticallyImplyLeading: false,
      titleSpacing: AppSpacing.lg,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      actions: [
        IconButton(
          tooltip: 'Settings',
          style: IconButton.styleFrom(
            backgroundColor: scheme.surface.withValues(alpha: 0.72),
            foregroundColor: scheme.onSurface,
            side: BorderSide(
              color: scheme.outlineVariant,
              width: AppStroke.hairline,
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
          onPressed: onSettingsTap,
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            _HeaderArtwork(phase: DayPhase.at(now)),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TickyMascot(
                    mood: mood,
                    idlePose: idlePose,
                    height: 132,
                    onTap: onMascotTap,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Greeting(now: now, message: message),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time-of-day artwork with a gradient behind it, so a missing image still
/// looks intentional, and a scrim in front so text stays readable.
class _HeaderArtwork extends StatelessWidget {
  const _HeaderArtwork({required this.phase});

  final DayPhase phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.slow,
      child: Stack(
        key: ValueKey(phase),
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: phase.fallbackGradient,
              ),
            ),
          ),
          Image.asset(
            phase.headerAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.62, 1],
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x330B0912),
                  AppColors.deepBackground,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now, required this.message});

  final DateTime now;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(greetingFor(now), style: text.headlineSmall, maxLines: 1),
        const SizedBox(height: 2),
        Text(
          formatLongDate(now),
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(animation),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          ),
          child: _SpeechBubble(key: ValueKey(message), message: message),
        ),
      ],
    );
  }
}

/// A chat bubble whose pointed corner faces Ticky on the left.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        border: Border.all(
          color: scheme.outlineVariant,
          width: AppStroke.hairline,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(AppRadius.xs),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
