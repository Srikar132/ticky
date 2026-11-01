import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/primary_action_button.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';

/// Shown instead of the checklist when there is nothing to show. Ticky is
/// already in the header (and speaks about it), so this adds no second mascot.
///
/// - [hasRoutines] false: a brand new user. Shows a faded example day, one
///   clear action, and quick-start suggestions.
/// - [hasRoutines] true: routines exist but none run today. Quiet and brief.
class EmptyTodayState extends StatelessWidget {
  const EmptyTodayState({
    super.key,
    required this.hasRoutines,
    required this.onAdd,
    required this.onSuggest,
  });

  final bool hasRoutines;
  final VoidCallback onAdd;
  final ValueChanged<TaskSuggestion> onSuggest;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl + AppSpacing.xl,
        ),
        child: hasRoutines
            ? _RestDay(onAdd: onAdd)
            : _NewUser(onAdd: onAdd, onSuggest: onSuggest),
      ),
    );
  }
}

class _NewUser extends StatelessWidget {
  const _NewUser({required this.onAdd, required this.onSuggest});

  final VoidCallback onAdd;
  final ValueChanged<TaskSuggestion> onSuggest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Build your day', style: text.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Add what you do each day. Ticky reminds you at the right time.',
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _ExampleDay(),
        const SizedBox(height: AppSpacing.xl),
        PrimaryActionButton(
          label: 'Create your first routine',
          onPressed: onAdd,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Or start with one of these',
          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final suggestion in taskSuggestions)
              ActionChip(
                avatar: Icon(suggestion.icon, size: 18, color: scheme.tertiary),
                label: Text(suggestion.title),
                onPressed: () => onSuggest(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

class _RestDay extends StatelessWidget {
  const _RestDay({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: scheme.outlineVariant,
              width: AppStroke.hairline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Icon(
              Icons.event_available_rounded,
              size: 28,
              color: scheme.secondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Nothing planned today',
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'None of your routines run today. Enjoy the free time, or add something new.',
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryActionButton(label: 'Add a task', onPressed: onAdd),
      ],
    );
  }
}

/// Three dashed, fading rows that hint at what the checklist will look like.
/// Purely decorative, so hidden from screen readers.
class _ExampleDay extends StatelessWidget {
  const _ExampleDay();

  static const _rows = [
    ('Morning walk', 7 * 60),
    ('Take vitamins', 8 * 60 + 30),
    ('Wind down', 22 * 60),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0x99FFFFFF), Color(0x1AFFFFFF)],
        ).createShader(rect),
        child: Column(
          children: [
            for (final (title, minutes) in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: CustomPaint(
                  painter: _DashedBorder(
                    color: scheme.outline,
                    radius: AppRadius.md,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md + 2,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.outline,
                              width: 1.5,
                            ),
                          ),
                          child: const SizedBox(width: 26, height: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          formatMinutesOfDay(minutes),
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A rounded rectangle drawn with dashes.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
