import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/features/home/models/daily_progress.dart';

/// Today's completion: "3 of 5 done" with a thin animated bar. A flat summary
/// with no box around it.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.progress});

  final DailyProgress progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final success = context.tickyColors.success;
    final done = progress.allDone;

    final headline = progress.allSkipped
        ? 'All skipped'
        : '${progress.completed} of ${progress.target} done';
    final subtitle = switch (progress) {
      DailyProgress(allDone: true) => 'Every task ticked. Perfect day!',
      DailyProgress(allSkipped: true) => 'Nothing left for today.',
      DailyProgress(remaining: 1) => 'Just 1 task to go',
      DailyProgress(:final remaining) => '$remaining tasks to go',
    };

    return Semantics(
      container: true,
      label: "Today's progress. $headline. $subtitle",

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's progress",
                  style: text.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: done
                    ? Icon(
                        Icons.celebration_rounded,
                        key: const ValueKey('done'),
                        size: 18,
                        color: success,
                      )
                    : const SizedBox.shrink(key: ValueKey('open')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(headline, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress.fraction),
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: done ? success : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: text.bodySmall),
        ],
      ),
    );
  }
}
