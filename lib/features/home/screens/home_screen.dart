import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/floating_nav_bar.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/celebration/widgets/all_done_sheet.dart';
import 'package:ticky/features/celebration/widgets/confetti.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/focus/widgets/focus_card.dart';
import 'package:ticky/features/home/models/daily_progress.dart';
import 'package:ticky/features/home/models/home_headline.dart';
import 'package:ticky/features/home/models/task_group.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/home/widgets/empty_state.dart';
import 'package:ticky/features/home/widgets/home_header.dart';
import 'package:ticky/features/home/widgets/notification_permission_sheet.dart';
import 'package:ticky/features/home/widgets/stat_info_sheet.dart';
import 'package:ticky/features/home/widgets/task_actions_sheet.dart';
import 'package:ticky/features/home/widgets/task_tile.dart';
import 'package:ticky/features/home/widgets/ticky_hero.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/routine/models/streak.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// Home: greeting and quick stats, a headline, Ticky with today's progress,
/// and the checklist grouped by time. Everything here is today only.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// A short-lived reaction (celebrating, surprised) that overrides the mood
  /// computed from the day.
  MascotMood? _reaction;
  Timer? _reactionTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerReminders());
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    super.dispose();
  }

  /// Landing on Home never triggers a system dialog. If reminders are off, we
  /// offer them in a friendly sheet and let the user decide.
  Future<void> _offerReminders() async {
    await Future<void>.delayed(ref.read(homePromptDelayProvider));
    if (!mounted) return;
    final due = await ref.read(notificationPromptDueProvider.future);
    if (!mounted || !due) return;
    await showNotificationPermissionSheet(context, ref);
  }

  void _react(MascotMood mood, {Duration hold = const Duration(seconds: 2)}) {
    _reactionTimer?.cancel();
    setState(() {
      _reaction = mood;
      _messageIndex++;
    });
    _reactionTimer = Timer(hold, () {
      if (mounted) setState(() => _reaction = null);
    });
  }

  void _showMessage(String text, {String? undoLabel, VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: onUndo == null
              ? null
              : SnackBarAction(label: undoLabel ?? 'Undo', onPressed: onUndo),
        ),
      );
  }

  /// Runs a task change and reports expected failures as a message.
  Future<bool> _attempt(Future<void> Function() change) async {
    try {
      await change();
      return true;
    } on DataException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    }
  }

  Future<void> _toggleComplete(
    DailyTaskEntry entry,
    DailyProgress progress,
  ) async {
    final actions = ref.read(taskActionsProvider);
    final id = entry.record.id;

    if (entry.record.status == TaskStatus.completed) {
      if (await _attempt(() => actions.reopen(id))) {
        AppFeedback.tap();
      }
      return;
    }

    final finishesDay =
        entry.record.status == TaskStatus.pending && progress.remaining == 1;
    if (!await _attempt(() => actions.complete(id)) || !mounted) return;
    final coins = coinsForPriority(entry.priority);

    if (finishesDay) {
      // The big moment: a full-screen burst, then a congratulations sheet.
      _react(MascotMood.celebrating, hold: const Duration(seconds: 5));
      unawaited(AppFeedback.celebrate());
      playConfetti(context, style: ConfettiStyle.party);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await showAllDoneSheet(context, coinsEarned: coins + perfectDayBonus);
      return;
    }

    AppFeedback.success();
    _react(MascotMood.excited);
  }

  Future<void> _toggleSkip(DailyTaskEntry entry) async {
    final actions = ref.read(taskActionsProvider);
    final id = entry.record.id;

    if (entry.record.status == TaskStatus.skipped) {
      await _attempt(() => actions.reopen(id));
      return;
    }
    if (!await _attempt(() => actions.skip(id))) return;
    AppFeedback.tap();
    _showMessage(
      'Skipped for today',
      onUndo: () => _attempt(() => actions.reopen(id)),
    );
  }

  Future<void> _snooze(DailyTaskEntry entry) async {
    final actions = ref.read(taskActionsProvider);
    try {
      final until = await actions.snooze(entry.record.id);
      AppFeedback.tap();
      if (mounted) {
        _showMessage(
          'Snoozed until ${formatMinutesOfDay(minutesOfDay(until))}',
        );
      }
    } on DataException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _openActions(
    DailyTaskEntry entry,
    DailyProgress progress,
  ) async {
    AppFeedback.tap();
    final action = await showTaskActionsSheet(context, entry);
    if (action == null || !mounted) return;
    switch (action) {
      case TaskQuickAction.complete:
      case TaskQuickAction.reopen:
        if (entry.record.status == TaskStatus.skipped) {
          await _toggleSkip(entry);
        } else {
          await _toggleComplete(entry, progress);
        }
      case TaskQuickAction.skip:
        await _toggleSkip(entry);
      case TaskQuickAction.snooze:
        await _snooze(entry);
      case TaskQuickAction.edit:
        await AppRoutes.openEditTask(context, entry.record.routineTaskId);
      case TaskQuickAction.details:
        await AppRoutes.openTaskDetails(context, entry.record.id);
    }
  }

  void _showStreakInfo(StreakInfo streak) {
    final count = streak.count;
    showStatInfoSheet(
      context,
      mood: count > 0 ? MascotMood.excited : MascotMood.idle,
      title: count == 0
          ? 'No streak yet'
          : count == 1
          ? '1 day streak'
          : '$count day streak',
      body: streak.includesToday
          ? "Today counts! You've done everything you planned."
          : 'Finish everything you planned today to extend it. Skipped tasks never break a streak.',
    );
  }

  void _showCoinInfo(int coins) {
    showStatInfoSheet(
      context,
      mood: MascotMood.happy,
      title: '$coins coins',
      body:
          'Earn coins by completing tasks, plus a bonus for a perfect day. Spend them on items for Ticky in Settings.',
      actionLabel: 'Open settings',
      onAction: () => AppRoutes.openSettings(context),
    );
  }

  Future<void> _refresh() => ref.read(reminderCoordinatorProvider).refresh();

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider)();
    final entriesAsync = ref.watch(todayEntriesProvider);
    final hasRoutinesAsync = ref.watch(hasRoutinesProvider);
    final streak = ref.watch(streakProvider).value ?? StreakInfo.none;
    final coins = ref.watch(coinBalanceProvider).value ?? 0;
    // Keeps the category list loaded, so the new-task page opens with its form
    // already filled in rather than waiting for the database.
    ref.watch(activeCategoriesProvider);
    final categories = {
      for (final c
          in ref.watch(allCategoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    final entries = entriesAsync.value ?? const <DailyTaskEntry>[];
    final hasRoutines = hasRoutinesAsync.value ?? false;
    final progress = DailyProgress.fromEntries(entries);

    final mood =
        _reaction ??
        mascotMoodFor(
          hasRoutines: hasRoutines,
          hasTasksToday: !progress.isEmpty,
          completed: progress.completed,
          progress: progress.fraction,
          allDone: progress.allDone,
          anyOverdue: hasOverdue(entries, now),
          dueSoon: hasDueSoon(entries, now),
          hour: now.hour,
        );

    final loading =
        (entriesAsync.isLoading && !entriesAsync.hasValue) ||
        (hasRoutinesAsync.isLoading && !hasRoutinesAsync.hasValue);
    final failed = entriesAsync.hasError && !entriesAsync.hasValue;

    final headline = homeHeadline(progress, hasRoutines: hasRoutines);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: HomeHeader(
                  now: now,
                  streak: streak,
                  coins: coins,
                  headline: headline,
                  onStreakTap: () => _showStreakInfo(streak),
                  onCoinsTap: () => _showCoinInfo(coins),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg + 4,
              ),
              sliver: SliverToBoxAdapter(
                child: TickyHero(
                  mood: mood,
                  idlePose: ref.watch(idlePoseProvider),
                  message: mascotMessage(mood, _messageIndex),
                  progress: entries.isEmpty ? null : progress,
                  onMascotTap: () => _react(MascotMood.surprised),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg + 4,
                AppSpacing.md,
                AppSpacing.lg + 4,
                0,
              ),
              sliver: SliverToBoxAdapter(child: FocusCard()),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (failed)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: AppSpacing.screen,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load your day.'),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(todayEntriesProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (entries.isEmpty)
              EmptyTodayState(
                hasRoutines: hasRoutines,
                onAdd: () => AppRoutes.openAddTask(context),
                onSuggest: (s) => AppRoutes.openAddTask(context, suggestion: s),
              )
            else ...[
              _ChecklistSliver(
                entries: entries,
                categories: categories,
                now: now,
                onToggleComplete: (e) => _toggleComplete(e, progress),
                onToggleSkip: _toggleSkip,
                onOpen: (e) => AppRoutes.openTaskDetails(context, e.record.id),
                onMore: (e) => _openActions(e, progress),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: FloatingNavBar.reservedHeight + AppSpacing.xl,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The grouped checklist, flattened into headers and rows.
class _ChecklistSliver extends StatelessWidget {
  const _ChecklistSliver({
    required this.entries,
    required this.categories,
    required this.now,
    required this.onToggleComplete,
    required this.onToggleSkip,
    required this.onOpen,
    required this.onMore,
  });

  final List<DailyTaskEntry> entries;
  final Map<int, Category> categories;
  final DateTime now;
  final void Function(DailyTaskEntry) onToggleComplete;
  final void Function(DailyTaskEntry) onToggleSkip;
  final void Function(DailyTaskEntry) onOpen;
  final void Function(DailyTaskEntry) onMore;

  @override
  Widget build(BuildContext context) {
    final items = <Object>[
      for (final group in groupEntriesByTime(entries)) ...[
        group,
        ...group.entries,
      ],
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + 4,
        AppSpacing.md,
        AppSpacing.lg + 4,
        0,
      ),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is TaskGroup) return _GroupHeader(group: item);
          final entry = item as DailyTaskEntry;
          return EntranceFade(
            key: ValueKey('entry-${entry.record.id}'),
            index: index,
            child: TaskTile(
              entry: entry,
              category: categories[entry.categoryId],
              now: now,
              onToggleComplete: () => onToggleComplete(entry),
              onToggleSkip: () => onToggleSkip(entry),
              onOpen: () => onOpen(entry),
              onMore: () => onMore(entry),
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final TaskGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = group.entries
        .where((e) => e.record.status != TaskStatus.pending)
        .length;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.md,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(child: Text(group.kind.label, style: text.titleMedium)),
            Text(
              '$done/${group.entries.length}',
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
