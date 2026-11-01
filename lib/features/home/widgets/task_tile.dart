import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/home/models/daily_progress.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// One checklist row.
///
/// - Tap the circle: complete, or undo.
/// - Swipe right: complete (or undo). Swipe left: skip (or undo). The row
///   springs back, because the list updates from the database.
/// - Tap: details. Long press: quick actions.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.entry,
    required this.category,
    required this.now,
    required this.onToggleComplete,
    required this.onToggleSkip,
    required this.onOpen,
    required this.onMore,
  });

  final DailyTaskEntry entry;
  final Category? category;
  final DateTime now;
  final VoidCallback onToggleComplete;
  final VoidCallback onToggleSkip;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final status = record.status;
    final colors = context.tickyColors;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final completed = status == TaskStatus.completed;
    final skipped = status == TaskStatus.skipped;
    final overdue = isOverdue(entry, now);
    final scheduled = record.scheduledMinutes;

    final titleStyle = text.titleMedium?.copyWith(
      decoration: completed ? TextDecoration.lineThrough : null,
      decorationColor: scheme.onSurfaceVariant,
      color: (completed || skipped) ? scheme.onSurfaceVariant : null,
    );

    // A flat row: no card, just a hairline under it.
    return Dismissible(
      key: ValueKey('task-${record.id}'),
      background: _SwipeBackground(
        color: colors.success,
        icon: completed ? Icons.undo_rounded : Icons.check_rounded,
        label: completed ? 'Undo' : 'Done',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: colors.warning,
        icon: skipped ? Icons.undo_rounded : Icons.skip_next_rounded,
        label: skipped ? 'Undo' : 'Skip',
        alignment: Alignment.centerRight,
      ),
      // Act, then refuse the dismissal: the stream rebuilds the row.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleComplete();
        } else {
          onToggleSkip();
        }
        return false;
      },
      child: AnimatedOpacity(
        duration: AppMotion.medium,
        opacity: (completed || skipped) ? 0.72 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            onLongPress: onMore,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant,
                    width: AppStroke.hairline,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    TaskCheck(status: status, onTap: onToggleComplete),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.titleSnapshot,
                              style: titleStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs + 2),
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (scheduled != null)
                                  _Meta(
                                    icon: overdue
                                        ? Icons.error_outline_rounded
                                        : Icons.schedule_rounded,
                                    label: overdue
                                        ? '${formatMinutesOfDay(scheduled)} · Overdue'
                                        : formatMinutesOfDay(scheduled),
                                    color: overdue
                                        ? colors.warning
                                        : scheme.onSurfaceVariant,
                                  ),
                                if (skipped)
                                  _Meta(
                                    icon: Icons.skip_next_rounded,
                                    label: 'Skipped',
                                    color: scheme.onSurfaceVariant,
                                  ),
                                if (category != null)
                                  _Meta(
                                    icon: iconForCategoryKey(category!.iconKey),
                                    label: category!.title,
                                    color: Color(category!.colorValue),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RewardBadge(
                      coins: coinsForPriority(entry.priority),
                      earned: completed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round check button. Pending is an empty ring, completed fills in with
/// a tick, skipped shows a dimmed skip icon.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.status, required this.onTap});

  final TaskStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = context.tickyColors.success;
    final completed = status == TaskStatus.completed;
    final skipped = status == TaskStatus.skipped;

    return Semantics(
      button: true,
      checked: completed,
      label: completed ? 'Completed, tap to undo' : 'Mark as done',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed
                    ? success
                    : skipped
                    ? scheme.surfaceContainerHighest
                    : Colors.transparent,
                border: Border.all(
                  color: completed ? success : scheme.outline,
                  width: 1.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: completed
                    ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        size: 20,
                        color: scheme.onPrimary,
                      )
                    : skipped
                    ? Icon(
                        Icons.skip_next_rounded,
                        key: const ValueKey('skip'),
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.coins, required this.earned});

  final int coins;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = context.tickyColors;
    final scheme = Theme.of(context).colorScheme;
    final color = earned ? colors.coin : scheme.onSurfaceVariant;
    return Semantics(
      label: earned ? '$coins coins earned' : '$coins coins reward',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_rounded, size: 16, color: color),
          const SizedBox(width: 3),
          Text(
            '+$coins',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2)),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a row in once, staggered by [index].
class EntranceFade extends StatelessWidget {
  const EntranceFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final start = math.min(index, 8) * 0.07;
    final curve = Interval(start, 1, curve: AppMotion.curve);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: curve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
