import 'package:flutter/material.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/floating_nav_bar.dart';
import 'package:ticky/core/widgets/primary_action_button.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';

/// Shown instead of the checklist when there is nothing to show. Ticky is
/// already in the hero card above, so this adds no second mascot.
///
/// - [hasRoutines] false: a brand new user. One clear action and pastel
///   quick-start tiles.
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
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 4,
        AppSpacing.xl,
        AppSpacing.lg + 4,
        FloatingNavBar.reservedHeight + AppSpacing.xl,
      ),
      sliver: SliverToBoxAdapter(
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
    final colors = context.tickyColors;
    final tints = [
      colors.tileBlue,
      colors.tilePink,
      colors.tileMint,
      colors.tileButter,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add what you do each day. Ticky reminds you at the right time.',
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryActionButton(
          label: 'Create your first routine',
          onPressed: onAdd,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Or start with one of these', style: text.titleSmall),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppSpacing.md;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, suggestion) in taskSuggestions.indexed)
                  SizedBox(
                    width: width,
                    child: _SuggestionTile(
                      suggestion: suggestion,
                      tint: tints[i % tints.length],
                      onTap: () => onSuggest(suggestion),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.tint,
    required this.onTap,
  });

  final TaskSuggestion suggestion;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: tint,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    suggestion.icon,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(suggestion.title, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(
                formatMinutesOfDay(suggestion.reminderMinutes),
                style: text.bodySmall?.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.tickyColors.tileMint,
            borderRadius: AppRadius.lgAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Icon(
              Icons.event_available_rounded,
              size: 28,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Nothing planned today', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'None of your routines run today. Enjoy the free time, or add something new.',
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryActionButton(label: 'Add a task', onPressed: onAdd),
      ],
    );
  }
}
