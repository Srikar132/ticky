import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// What the user chose in the time sheet. A null [minutes] means "no
/// reminder" (an Anytime task).
class ReminderTimeChoice {
  const ReminderTimeChoice(this.minutes);

  final int? minutes;
}

/// Bottom sheet with a time wheel. Returns null when dismissed.
Future<ReminderTimeChoice?> showReminderTimeSheet(
  BuildContext context, {
  required int initialMinutes,
  required bool canClear,
}) {
  return showModalBottomSheet<ReminderTimeChoice>(
    context: context,
    useSafeArea: true,
    builder: (_) =>
        _ReminderTimeSheet(initialMinutes: initialMinutes, canClear: canClear),
  );
}

class _ReminderTimeSheet extends StatefulWidget {
  const _ReminderTimeSheet({
    required this.initialMinutes,
    required this.canClear,
  });

  final int initialMinutes;
  final bool canClear;

  @override
  State<_ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<_ReminderTimeSheet> {
  late int _minutes = widget.initialMinutes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
            Text('Reminder time', style: text.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 190,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    widget.initialMinutes ~/ 60,
                    widget.initialMinutes % 60,
                  ),
                  onDateTimeChanged: (value) =>
                      _minutes = value.hour * 60 + value.minute,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(ReminderTimeChoice(_minutes)),
              child: const Text('Set time'),
            ),
            if (widget.canClear) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const ReminderTimeChoice(null)),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('No reminder (Anytime)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
