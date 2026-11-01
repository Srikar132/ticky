import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/time_formatting.dart';

const _snoozeChoices = [5, 10, 15, 30, 60];

/// Bottom sheet to pick the default snooze length. Returns the chosen minutes,
/// or null when dismissed.
Future<int?> showSnoozeSheet(BuildContext context, {required int current}) {
  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    builder: (_) => _SnoozeSheet(current: current),
  );
}

class _SnoozeSheet extends StatelessWidget {
  const _SnoozeSheet({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final choices = {..._snoozeChoices, current}.toList()..sort();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Default snooze', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How long a reminder waits when you snooze it. A task can set its own.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final minutes in choices)
                  ChoiceChip(
                    label: Text(formatDuration(minutes)),
                    selected: minutes == current,
                    onSelected: (_) => Navigator.of(context).pop(minutes),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
