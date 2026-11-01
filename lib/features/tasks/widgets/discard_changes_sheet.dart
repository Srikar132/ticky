import 'package:flutter/material.dart';
import 'package:ticky/core/widgets/confirm_sheet.dart';

/// Asks before leaving a form with unsaved changes. Returns true to discard.
Future<bool> showDiscardChangesSheet(BuildContext context) {
  return showConfirmSheet(
    context,
    title: 'Discard changes?',
    message: 'What you changed on this task has not been saved.',
    keepLabel: 'Keep editing',
    confirmLabel: 'Discard',
  );
}
