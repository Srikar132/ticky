import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/focus/models/carry_offer.dart';

/// "Yesterday's focus" for the title of the offer, or the weekday when the last
/// written day was earlier.
String offerDayLabel(CarryOffer offer, String todayKey) {
  final days = parseDateKey(
    todayKey,
  ).difference(parseDateKey(offer.sourceDateKey)).inDays;
  if (days == 1) return "yesterday's";
  return "${DateFormat('EEEE').format(parseDateKey(offer.sourceDateKey))}'s";
}

/// The facts line: "3 goals · 2 unfinished", or a note-only message.
String offerSummary(CarryOffer offer) {
  if (offer.goals == 0) return 'A note you wrote';
  final goals = offer.goals == 1 ? '1 goal' : '${offer.goals} goals';
  if (offer.unfinished == 0) return '$goals · all done';
  return '$goals · ${offer.unfinished} unfinished';
}

/// A small dark, fully round button. The one strong action of a surface.
class InkPill extends StatelessWidget {
  const InkPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// False draws a soft pill for a second choice.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = filled ? scheme.onInverseSurface : scheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? scheme.inverseSurface : scheme.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          enableFeedback: false,
          onTap: () {
            AppFeedback.tap();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks whether to bring an earlier day's focus over. Used inside the Home card
/// and at the top of the editor, so the question reads the same in both.
class FocusOfferPanel extends StatelessWidget {
  const FocusOfferPanel({
    super.key,
    required this.offer,
    required this.todayKey,
    required this.onAccept,
    required this.onDecline,
  });

  final CarryOffer offer;
  final String todayKey;

  /// Called with `unfinishedOnly`.
  final void Function({required bool unfinishedOnly}) onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mixed = offer.hasMixedProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bring ${offerDayLabel(offer, todayKey)} focus over?',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          offerSummary(offer),
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkPill(
              label: mixed
                  ? 'Bring ${offer.unfinished} unfinished'
                  : 'Bring it over',
              icon: Icons.south_west_rounded,
              onTap: () => onAccept(unfinishedOnly: mixed),
            ),
            if (mixed)
              InkPill(
                label: 'Copy all',
                filled: false,
                onTap: () => onAccept(unfinishedOnly: false),
              ),
            TextButton(
              onPressed: () {
                AppFeedback.tap();
                onDecline();
              },
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Start fresh'),
            ),
          ],
        ),
      ],
    );
  }
}
