import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/color_tones.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/celebration/widgets/confetti.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/home/models/daily_progress.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// One checklist row: a white rounded card.
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
    final coins = coinsForPriority(entry.priority);

    final titleStyle = text.titleMedium?.copyWith(
      decoration: completed ? TextDecoration.lineThrough : null,
      decorationColor: scheme.onSurfaceVariant,
      color: (completed || skipped) ? scheme.onSurfaceVariant : null,
    );

    final timeLabel = scheduled == null
        ? null
        : overdue
        ? '${formatMinutesOfDay(scheduled)} · Overdue'
        : formatMinutesOfDay(scheduled);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Dismissible(
          key: ValueKey('task-${record.id}'),
          background: _SwipeBackground(
            color: colors.tileMint,
            foreground: colors.success,
            icon: completed ? Icons.undo_rounded : Icons.check_rounded,
            label: completed ? 'Undo' : 'Done',
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: _SwipeBackground(
            color: colors.tileButter,
            foreground: colors.warning,
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
          child: Material(
            color: scheme.surfaceContainerLow,
            child: InkWell(
              onTap: onOpen,
              onLongPress: onMore,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    TaskCheck(status: status, onTap: onToggleComplete),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm + 2,
                        ),
                        child: AnimatedOpacity(
                          duration: AppMotion.medium,
                          opacity: (completed || skipped) ? 0.6 : 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.titleSnapshot,
                                style: titleStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timeLabel != null ||
                                  skipped ||
                                  category != null) ...[
                                const SizedBox(height: AppSpacing.xs + 2),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (timeLabel != null || skipped)
                                      Text(
                                        skipped
                                            ? (timeLabel == null
                                                  ? 'Skipped'
                                                  : '$timeLabel · Skipped')
                                            : timeLabel!,
                                        style: text.bodySmall?.copyWith(
                                          color: overdue && !skipped
                                              ? colors.warning
                                              : scheme.onSurfaceVariant,
                                          fontWeight: overdue && !skipped
                                              ? FontWeight.w600
                                              : null,
                                        ),
                                      ),
                                    if (category != null)
                                      _CategoryPill(category: category!),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _RewardBadge(coins: coins, earned: completed),
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
///
/// When a task becomes completed, a small confetti pop bursts from the circle.
class TaskCheck extends StatefulWidget {
  const TaskCheck({super.key, required this.status, required this.onTap});

  final TaskStatus status;
  final VoidCallback onTap;

  @override
  State<TaskCheck> createState() => _TaskCheckState();
}

class _TaskCheckState extends State<TaskCheck> {
  @override
  void didUpdateWidget(TaskCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != TaskStatus.completed &&
        widget.status == TaskStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pop());
    }
  }

  void _pop() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    playConfetti(
      context,
      origin: box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.status;
    final completed = status == TaskStatus.completed;
    final skipped = status == TaskStatus.skipped;

    return Semantics(
      button: true,
      checked: completed,
      label: completed ? 'Completed, tap to undo' : 'Mark as done',
      excludeSemantics: true,
      child: InkResponse(
        enableFeedback: false,
        onTap: widget.onTap,
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
                    ? scheme.inverseSurface
                    : skipped
                    ? scheme.surfaceContainerHighest
                    : Colors.transparent,
                border: Border.all(
                  color: completed ? scheme.inverseSurface : scheme.outline,
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
                        color: scheme.onInverseSurface,
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

/// The category as a small pastel pill.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final accent = Color(category.colorValue);
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.soft(brightness),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconForCategoryKey(category.iconKey),
              size: 13,
              color: accent.deep(brightness),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent.deep(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "+2" in a soft butter pill. Fills in once the coins are earned.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.coins, required this.earned});

  final int coins;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = context.tickyColors;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: earned ? '$coins coins earned' : '$coins coins reward',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: earned ? colors.tileButter : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          '+$coins',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: earned ? colors.coin : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
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
