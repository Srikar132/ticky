import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/features/celebration/data/celebration_quotes.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';

/// Shown when the last task of the day is done: congratulations, the coins
/// earned, and a random line from [celebrationQuotes]. One OK button.
///
/// Pass [quote] to fix the line, for tests.
Future<void> showAllDoneSheet(
  BuildContext context, {
  required int coinsEarned,
  CelebrationQuote? quote,
}) {
  final line = quote ?? randomCelebrationQuote();
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      final scheme = Theme.of(sheetContext).colorScheme;
      final colors = sheetContext.tickyColors;
      return SingleChildScrollView(
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
            Center(
              child: TickyMascot(mood: MascotMood.celebrating, height: 120),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Congratulations!',
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You finished everything on your list today.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (coinsEarned > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.tileButter,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          size: 20,
                          color: colors.coin,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '+$coinsEarned coins today',
                          style: text.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tileLavender,
                borderRadius: AppRadius.lgAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg + 2),
                child: Column(
                  children: [
                    Text(
                      '“${line.text}”',
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      line.author,
                      style: text.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
  );
}
