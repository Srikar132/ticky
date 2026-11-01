import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';

/// A small friendly sheet explaining a number on Home (streak, coins).
Future<void> showStatInfoSheet(
  BuildContext context, {
  required MascotMood mood,
  required String title,
  required String body,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      final scheme = Theme.of(sheetContext).colorScheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: TickyMascot(mood: mood, height: 100)),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (actionLabel != null && onAction != null) ...[
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onAction();
                },
                child: Text(actionLabel),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    },
  );
}
