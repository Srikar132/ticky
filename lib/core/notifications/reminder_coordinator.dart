import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/routine/data/daily_reconciler.dart';

/// Keeps the daily checklist and the scheduled reminders current.
///
/// - On start, on resume, and shortly after local midnight (if the app stays
///   open): run the daily reconcile, then sync notifications.
/// - On any change to routines, daily records or settings: sync notifications
///   (debounced). Callers never have to remember to reschedule.
///
/// Nothing here relies on background execution: scheduled notifications are
/// held by the OS, and everything is re-aligned whenever the app runs.
class ReminderCoordinator with WidgetsBindingObserver {
  ReminderCoordinator({
    required AppDatabase database,
    required DailyReconciler reconciler,
    required NotificationService notifications,
    required Clock clock,
    this.debounce = const Duration(milliseconds: 300),
    this.observeLifecycle = true,
  }) : _db = database,
       _reconciler = reconciler,
       _notifications = notifications,
       _clock = clock;

  final AppDatabase _db;
  final DailyReconciler _reconciler;
  final NotificationService _notifications;
  final Clock _clock;
  final Duration debounce;
  final bool observeLifecycle;

  StreamSubscription<Set<TableUpdate>>? _updates;
  Timer? _debounceTimer;
  Timer? _midnightTimer;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _notifications.initialize();
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    await refresh();
    _updates = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.routineTasks,
            _db.dailyTaskRecords,
            _db.appSettings,
          ]),
        )
        .listen((_) => _scheduleSync());
  }

  /// Daily reconcile, then notification sync.
  Future<void> refresh() async {
    _armMidnightTimer();
    await _reconciler.reconcile(_clock());
    await _notifications.sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_safeRefresh());
  }

  void dispose() {
    if (observeLifecycle && _started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _updates?.cancel();
    _debounceTimer?.cancel();
    _midnightTimer?.cancel();
    _started = false;
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(_safeSync()));
  }

  /// A new local day starts while the app is open: refresh just after it.
  void _armMidnightTimer() {
    _midnightTimer?.cancel();
    final now = _clock();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 5),
      () => unawaited(_safeRefresh()),
    );
  }

  Future<void> _safeRefresh() async {
    try {
      await refresh();
    } on Object catch (error, stack) {
      debugPrint('Reminder refresh failed: $error\n$stack');
    }
  }

  Future<void> _safeSync() async {
    try {
      await _notifications.sync();
    } on Object catch (error, stack) {
      debugPrint('Reminder sync failed: $error\n$stack');
    }
  }
}
