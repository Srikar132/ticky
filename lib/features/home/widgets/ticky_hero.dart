import 'package:flutter/material.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/home/models/daily_progress.dart';

/// The big lavender card at the top of Home: Ticky, what Ticky says, and
/// today's progress. This is the only place Ticky appears on Home.
class TickyHero extends StatelessWidget {
  const TickyHero({
    super.key,
    required this.mood,
    required this.message,
    required this.progress,
    required this.onMascotTap,
    this.idlePose,
  });

  final MascotMood mood;
  final String message;

  /// Null while there is nothing planned, which hides the progress.
  final DailyProgress? progress;
  final VoidCallback onMascotTap;

  /// The pose from the item shop that Ticky wears while idle, or null.
  final String? idlePose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final data = progress;
    final done = data?.allDone ?? false;

    return Semantics(
      container: true,
      label: data == null
          ? message
          : "Today's progress. ${_headline(data)}. $message",
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.tickyColors.tileLavender,
          borderRadius: AppRadius.xlAll,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg + 4,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      child: Text(
                        message,
                        key: ValueKey(message),
                        style: text.bodyLarge,
                      ),
                    ),
                    if (data != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Progress(progress: data, done: done),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TickyMascot(
                mood: mood,
                idlePose: idlePose,
                height: 124,
                onTap: onMascotTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headline(DailyProgress p) =>
      p.allSkipped ? 'All skipped' : '${p.completed} of ${p.target} done';
}

class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.done});

  final DailyProgress progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              progress.allSkipped ? '–' : '${progress.completed}',
              style: text.displaySmall?.copyWith(fontSize: 44, height: 1),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                progress.allSkipped
                    ? 'all skipped'
                    : 'of ${progress.target} done',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress.fraction),
          duration: AppMotion.slow,
          curve: AppMotion.curve,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: scheme.inverseSurface,
              backgroundColor: scheme.surface.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}
