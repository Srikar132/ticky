import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/focus/models/focus_markdown.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';
import 'package:ticky/features/focus/widgets/focus_block_views.dart';
import 'package:ticky/features/routine/data/history_repository.dart';
import 'package:ticky/features/routine/providers/history_providers.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// How many past days show before "Show older days".
const historyPreviewDays = 7;

/// Past days, newest first. Read-only: tap a day to see what happened, and a
/// task to see its details.
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key});

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  bool _showAll = false;

  Future<void> _openDay(String dateKey) async {
    final recordId = await showHistoryDaySheet(context, dateKey);
    if (recordId != null && mounted) {
      await AppRoutes.openTaskDetails(context, recordId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(historyDaysProvider).value ?? const <DaySummary>[];
    final shown = _showAll ? days : days.take(historyPreviewDays).toList();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('History'),
        if (days.isEmpty)
          Text(
            'Finished days show up here.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          FormCard(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const Divider(),
                _DayRow(day: shown[i], onTap: () => _openDay(shown[i].dateKey)),
              ],
              if (days.length > historyPreviewDays) ...[
                const Divider(),
                FormRow(
                  icon: _showAll
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  label: _showAll ? 'Show fewer days' : 'Show older days',
                  onTap: () => setState(() => _showAll = !_showAll),
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onTap});

  final DaySummary day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tickyColors;
    final scheme = Theme.of(context).colorScheme;
    final allSkipped = day.completed == 0 && day.undone == 0;
    final (icon, color) = day.isPerfect
        ? (Icons.check_circle_rounded, colors.success)
        : allSkipped
        ? (Icons.remove_circle_outline_rounded, scheme.onSurfaceVariant)
        : (Icons.circle_outlined, scheme.onSurfaceVariant);
    final value = allSkipped
        ? 'All skipped'
        : '${day.completed} of ${day.total} done';
    return FormRow(
      key: ValueKey('day-${day.dateKey}'),
      icon: icon,
      iconColor: color,
      label: formatShortDate(parseDateKey(day.dateKey)),
      value: value,
      onTap: onTap,
    );
  }
}

/// Bottom sheet listing what happened on one past day. Returns the id of the
/// record the user tapped, to open its details, or null.
Future<int?> showHistoryDaySheet(BuildContext context, String dateKey) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DaySheet(dateKey: dateKey),
  );
}

class _DaySheet extends ConsumerWidget {
  const _DaySheet({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(historyDayEntriesProvider(dateKey)).value ??
        const <DailyTaskEntry>[];
    final note = ref.watch(focusNoteProvider(dateKey)).value ?? '';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatLongDate(parseDateKey(dateKey)), style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Past days are read-only',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in entries)
                    _EntryRow(
                      entry: entry,
                      onTap: () => Navigator.of(context).pop(entry.record.id),
                    ),
                  if (note.trim().isNotEmpty) ...[
                    const SectionLabel("That day's focus"),
                    FocusPreviewList(blocks: parseFocusMarkdown(note)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final DailyTaskEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final colors = context.tickyColors;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (record.status) {
      TaskStatus.completed => (
        Icons.check_circle_rounded,
        colors.success,
        'Done',
      ),
      TaskStatus.skipped => (
        Icons.remove_circle_outline_rounded,
        scheme.onSurfaceVariant,
        'Skipped',
      ),
      TaskStatus.missed => (
        Icons.error_outline_rounded,
        colors.warning,
        'Missed',
      ),
      TaskStatus.pending => (
        Icons.circle_outlined,
        scheme.onSurfaceVariant,
        'Not done',
      ),
    };
    final time = record.scheduledMinutes;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color, semanticLabel: label),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                record.titleSnapshot,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (time != null)
              Text(
                formatMinutesOfDay(time),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
