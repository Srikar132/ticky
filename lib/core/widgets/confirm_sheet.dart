import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// A quiet two-choice bottom sheet for decisions that are hard to undo.
///
/// The safe choice ([keepLabel]) is the solid button; the risky one
/// ([confirmLabel]) is a plain text button in the error colour. Returns true
/// only when the risky choice is picked; dismissing the sheet counts as no.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String keepLabel,
  required String confirmLabel,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) {
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
              Text(title, style: text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(keepLabel),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: scheme.error,
                ),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
