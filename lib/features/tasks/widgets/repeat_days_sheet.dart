import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/tasks/models/repeat_days.dart';
import 'package:ticky/features/tasks/models/task_form_state.dart';
import 'package:ticky/features/tasks/providers/task_form_controller.dart';

/// Bottom sheet to pick the weekdays a task repeats on. Changes apply to the
/// form straight away; the sheet only closes with "Done".
Future<void> showRepeatDaysSheet(BuildContext context, TaskFormArgs args) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => _RepeatDaysSheet(args: args),
  );
}

class _RepeatDaysSheet extends ConsumerWidget {
  const _RepeatDaysSheet({required this.args});

  final TaskFormArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final provider = taskFormControllerProvider(args);
    final form = ref.watch(provider).value;
    final controller = ref.read(provider.notifier);
    final mask = form?.values.repeatDays ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Repeat', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              repeatSummary(mask),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayChip(
                    key: ValueKey('repeat-day-$i'),
                    initial: weekdayInitials[i],
                    name: weekdayShortNames[i],
                    selected: mask & (1 << i) != 0,
                    onTap: () => controller.toggleDay(i),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ActionChip(
                  label: const Text('Every day'),
                  onPressed: () => controller.setRepeatDays(127),
                ),
                ActionChip(
                  label: const Text('Weekdays'),
                  onPressed: () => controller.setRepeatDays(weekdaysMask),
                ),
                ActionChip(
                  label: const Text('Weekends'),
                  onPressed: () => controller.setRepeatDays(weekendMask),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: mask == 0 ? null : () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
            if (mask == 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Pick at least one day',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.initial,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String initial;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                initial,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
