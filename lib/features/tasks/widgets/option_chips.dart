import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// A single-choice row of chips over minute values. Null stands for "no
/// value" (for example "None" or "Default").
///
/// If the current value is not one of [presets] (an older custom value), it is
/// added so it stays visible and selected.
class MinuteChips extends StatelessWidget {
  const MinuteChips({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelected,
    required this.labelFor,
    required this.nullLabel,
  });

  final List<int> presets;
  final int? selected;
  final ValueChanged<int?> onSelected;
  final String Function(int minutes) labelFor;
  final String nullLabel;

  @override
  Widget build(BuildContext context) {
    final values = <int?>[
      null,
      ...{...presets, ?selected}.toList()..sort(),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(value == null ? nullLabel : labelFor(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}
