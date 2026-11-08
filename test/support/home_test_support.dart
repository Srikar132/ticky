import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/categories/data/category_repository.dart';
import 'package:ticky/features/categories/models/category_draft.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/focus/data/focus_repository.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/home/providers/notification_prompt_controller.dart';
import 'package:ticky/features/rewards/models/shop_item.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/routine/data/history_repository.dart';
import 'package:ticky/features/routine/providers/history_providers.dart';
import 'package:ticky/features/routine/models/streak.dart';
import 'package:ticky/features/settings/data/settings_repository.dart';
import 'package:ticky/features/settings/models/feedback_prefs.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/data/routine_repository.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';
import 'package:ticky/features/tasks/providers/routine_actions.dart';
import 'package:ticky/features/tasks/providers/task_details_providers.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// A checklist row for tests. [minutes] null means "anytime".
DailyTaskEntry entry({
  required int id,
  String title = 'Task',
  int? minutes,
  TaskStatus status = TaskStatus.pending,
  Priority priority = Priority.medium,
  int categoryId = 1,
}) {
  return DailyTaskEntry(
    record: DailyTaskRecord(
      id: id,
      routineTaskId: id,
      dateKey: '2026-11-02',
      titleSnapshot: title,
      scheduledMinutes: minutes,
      status: status,
      completedAt: status == TaskStatus.completed
          ? DateTime.utc(2026, 11, 2)
          : null,
    ),
    priority: priority,
    categoryId: categoryId,
  );
}

Category category({
  int id = 1,
  String title = 'General',
  String iconKey = 'check_circle',
}) {
  final stamp = DateTime.utc(2026);
  return Category(
    id: id,
    key: id == 1 ? 'general' : null,
    title: title,
    iconKey: iconKey,
    colorValue: 0xFF7C8DB5,
    sortOrder: id,
    isDefault: id == 1,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// Records what the UI asked for instead of touching a database.
class FakeTaskActions implements TaskActions {
  final calls = <String>[];
  Object? failWith;

  Future<void> _record(String call) async {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> complete(int recordId) => _record('complete:$recordId');

  @override
  Future<void> skip(int recordId) => _record('skip:$recordId');

  @override
  Future<void> reopen(int recordId) => _record('reopen:$recordId');

  @override
  Future<DateTime> snooze(int recordId) async {
    await _record('snooze:$recordId');
    return DateTime(2026, 11, 2, 9, 10);
  }
}

/// A routine as the form would load it.
RoutineTask routine({
  int id = 1,
  String title = 'Drink water',
  int? reminderMinutes = 480,
  bool alarmEnabled = false,
  int repeatDays = 127,
  Priority priority = Priority.medium,
  int categoryId = 1,
  int? durationMinutes,
  String? customReminderMessage,
  int? snoozeMinutes,
  String? description,
  DateTime? archivedAt,
}) {
  final stamp = DateTime.utc(2026);
  return RoutineTask(
    id: id,
    title: title,
    description: description,
    reminderMinutes: reminderMinutes,
    alarmEnabled: alarmEnabled,
    repeatDays: repeatDays,
    priority: priority,
    categoryId: categoryId,
    durationMinutes: durationMinutes,
    customReminderMessage: customReminderMessage,
    snoozeMinutes: snoozeMinutes,
    sortOrder: id,
    isEnabled: true,
    archivedAt: archivedAt,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// Records what the form saved instead of touching a database. It runs the
/// same [RoutineDraft] validation as the real repository.
class FakeRoutineRepository implements RoutineRepository {
  FakeRoutineRepository([Iterable<RoutineTask> routines = const []])
    : routines = {for (final r in routines) r.id: r};

  final Map<int, RoutineTask> routines;
  final created = <RoutineDraft>[];
  final updated = <int, RoutineDraft>{};

  @override
  Future<RoutineTask?> getById(int id) async => routines[id];

  @override
  Future<int> create(RoutineDraft draft) async {
    draft.validate();
    created.add(draft);
    return 100 + created.length;
  }

  @override
  Future<void> update(int id, RoutineDraft draft) async {
    draft.validate();
    updated[id] = draft;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Records deletes from Task Details instead of touching a database.
class FakeRoutineActions implements RoutineActions {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> delete(int routineId) async {
    calls.add('delete:$routineId');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> undoDelete(int routineId) async =>
      calls.add('undoDelete:$routineId');

  @override
  Future<void> setEnabled(int routineId, bool enabled) async {
    calls.add('setEnabled:$routineId:$enabled');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> reorder(List<int> orderedIds) async =>
      calls.add('reorder:${orderedIds.join(',')}');
}

/// Records notification settings changes instead of touching a database.
class FakeSettingsActions implements SettingsActions {
  final calls = <String>[];

  /// What [setRemindersEnabled] answers: whether to offer the permission sheet.
  bool needsPermission = false;

  @override
  Future<bool> setRemindersEnabled(bool enabled) async {
    calls.add('reminders:$enabled');
    return enabled && needsPermission;
  }

  @override
  Future<void> setSoundEnabled(bool enabled) async =>
      calls.add('sound:$enabled');

  @override
  Future<void> setVibrationEnabled(bool enabled) async =>
      calls.add('vibration:$enabled');

  @override
  Future<void> setFollowUpEnabled(bool enabled) async =>
      calls.add('followUp:$enabled');

  @override
  Future<void> setDefaultSnoozeMinutes(int minutes) async =>
      calls.add('snooze:$minutes');

  @override
  Future<void> setHapticsEnabled(bool enabled) async =>
      calls.add('haptics:$enabled');

  @override
  Future<void> setSoundEffectsEnabled(bool enabled) async =>
      calls.add('soundEffects:$enabled');
}

/// Starts on a fixed theme and records choices instead of saving them.
class FakeThemeModeController extends ThemeModeController {
  FakeThemeModeController([this.initial = ThemeMode.light]);

  final ThemeMode initial;
  final selected = <ThemeMode>[];

  @override
  ThemeMode build() => initial;

  @override
  Future<void> select(ThemeMode mode) async {
    selected.add(mode);
    state = mode;
  }
}

/// Records shop purchases instead of touching a database.
class FakeShopActions implements ShopActions {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> buy(ShopItem item) async {
    calls.add('buy:${item.key}');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> equip(String? itemKey) async => calls.add('equip:$itemKey');
}

/// Records category changes. Runs the same [CategoryDraft] validation as the
/// real repository.
class FakeCategoryRepository implements CategoryRepository {
  final created = <CategoryDraft>[];
  final updated = <int, CategoryDraft>{};
  final archived = <int>[];

  @override
  Future<int> create(CategoryDraft draft) async {
    draft.validate();
    created.add(draft);
    return 9;
  }

  @override
  Future<void> update(int id, CategoryDraft draft) async {
    draft.validate();
    updated[id] = draft;
  }

  @override
  Future<void> archive(int id) async => archived.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Answers the permission question the form asks after saving.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.notificationsAllowed = true});

  bool notificationsAllowed;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async =>
      NotificationPermissionStatus(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: true,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Stands in for the settings table: remembers the "maybe later" time.
class FakeSettings implements SettingsRepository {
  DateTime? dismissedAt;
  String? focusCarryAnswered;

  @override
  Future<String?> getFocusCarryAnsweredDateKey() async => focusCarryAnswered;

  @override
  Future<void> setFocusCarryAnsweredDateKey(String dateKey) async =>
      focusCarryAnswered = dateKey;

  @override
  Future<DateTime?> getNotificationPromptDismissedAt() async => dismissedAt;

  @override
  Future<void> setNotificationPromptDismissedAt(DateTime at) async =>
      dismissedAt = at;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Today's focus notebook kept in a map instead of a database. Like the real
/// one, a blank body removes the day.
class FakeFocusRepository implements FocusRepository {
  FakeFocusRepository([Map<String, String> notes = const {}])
    : notes = {...notes};

  final Map<String, String> notes;
  final saves = <(String, String)>[];

  @override
  Future<String> getBody(String dateKey) async => notes[dateKey] ?? '';

  @override
  Stream<String> watchBody(String dateKey) =>
      Stream.value(notes[dateKey] ?? '');

  @override
  Future<DayNote?> latestBefore(String dateKey) async {
    final earlier = notes.keys.where((k) => k.compareTo(dateKey) < 0).toList()
      ..sort();
    if (earlier.isEmpty) return null;
    final key = earlier.last;
    return DayNote(
      dateKey: key,
      body: notes[key]!,
      updatedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<void> save(String dateKey, String body) async {
    saves.add((dateKey, body));
    if (body.trim().isEmpty) {
      notes.remove(dateKey);
    } else {
      notes[dateKey] = body;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// A prompt controller that answers instantly, like a granted permission.
class FakePromptController extends NotificationPromptController {
  FakePromptController({this.result = PromptStep.done});

  final PromptStep result;
  int enableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
    state = PromptStep.working;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = result;
  }

  @override
  Future<void> allowExactTiming() async => state = PromptStep.done;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> recheck() async {}
}

/// A phone-sized, fixed-time Home. No database, no timers.
List<Override> homeOverrides({
  List<DailyTaskEntry> entries = const [],
  bool hasRoutines = true,
  StreakInfo streak = StreakInfo.none,
  int coins = 0,
  List<Category>? categories,
  bool promptDue = false,
  DateTime? now,
  FakeTaskActions? actions,
  FakeSettings? settings,
  FakePromptController? prompt,
  FakeRoutineRepository? routines,
  FakeNotificationService? notifications,
  FakeRoutineActions? routineActions,

  // Settings.
  NotificationPrefs prefs = const NotificationPrefs(),
  bool notificationsAllowed = true,
  List<RoutineTask> activeRoutines = const [],
  Set<String> unlockedItems = const {},
  String? equippedItem,
  List<DaySummary> historyDays = const [],
  Map<String, List<DailyTaskEntry>> historyEntries = const {},
  FakeSettingsActions? settingsActions,
  FakeShopActions? shopActions,
  FakeCategoryRepository? categoryRepository,
  ThemeMode themeMode = ThemeMode.light,
  FakeThemeModeController? themeController,
  FeedbackPrefs feedbackPrefs = const FeedbackPrefs(),
  FakeFocusRepository? focus,
}) {
  final time = now ?? DateTime(2026, 11, 2, 9);
  final fakeRoutines = routines ?? FakeRoutineRepository();
  return [
    focusRepositoryProvider.overrideWithValue(focus ?? FakeFocusRepository()),
    focusSaveDelayProvider.overrideWithValue(Duration.zero),
    themeModeProvider.overrideWith(
      () => themeController ?? FakeThemeModeController(themeMode),
    ),
    feedbackPrefsProvider.overrideWith((ref) => Stream.value(feedbackPrefs)),
    notificationPrefsProvider.overrideWith((ref) => Stream.value(prefs)),
    notificationPermissionProvider.overrideWith(
      (ref) async => NotificationPermissionStatus(
        notificationsAllowed: notificationsAllowed,
        exactAlarmsAllowed: true,
      ),
    ),
    activeRoutinesProvider.overrideWith((ref) => Stream.value(activeRoutines)),
    unlockedItemKeysProvider.overrideWith((ref) => Stream.value(unlockedItems)),
    equippedItemKeyProvider.overrideWith((ref) => Stream.value(equippedItem)),
    idlePoseProvider.overrideWith((ref) {
      final item = shopItemFor(equippedItem);
      return item != null && unlockedItems.contains(item.key)
          ? item.pose
          : null;
    }),
    historyDaysProvider.overrideWith((ref) => Stream.value(historyDays)),
    historyDayEntriesProvider.overrideWith(
      (ref, dateKey) => Stream.value(historyEntries[dateKey] ?? const []),
    ),
    settingsActionsProvider.overrideWithValue(
      settingsActions ?? FakeSettingsActions(),
    ),
    shopActionsProvider.overrideWithValue(shopActions ?? FakeShopActions()),
    categoryRepositoryProvider.overrideWithValue(
      categoryRepository ?? FakeCategoryRepository(),
    ),
    detailRecordProvider.overrideWith(
      (ref, id) => Stream.value(
        entries.where((e) => e.record.id == id).firstOrNull?.record,
      ),
    ),
    detailRoutineProvider.overrideWith(
      (ref, id) => Stream.value(fakeRoutines.routines[id]),
    ),
    routineActionsProvider.overrideWithValue(
      routineActions ?? FakeRoutineActions(),
    ),
    activeCategoriesProvider.overrideWith(
      (ref) => Stream.value(categories ?? [category()]),
    ),
    routineRepositoryProvider.overrideWithValue(fakeRoutines),
    notificationServiceProvider.overrideWithValue(
      notifications ?? FakeNotificationService(),
    ),
    clockProvider.overrideWithValue(() => time),
    nowProvider.overrideWith((ref) => Stream.value(time)),
    todayKeyProvider.overrideWith((ref) => Stream.value(dateKeyOf(time))),
    todayEntriesProvider.overrideWith((ref) => Stream.value(entries)),
    hasRoutinesProvider.overrideWith((ref) => Stream.value(hasRoutines)),
    streakProvider.overrideWith((ref) => Stream.value(streak)),
    coinBalanceProvider.overrideWith((ref) => Stream.value(coins)),
    allCategoriesProvider.overrideWith(
      (ref) => Stream.value(categories ?? [category()]),
    ),
    notificationPromptDueProvider.overrideWith((ref) async => promptDue),
    homePromptDelayProvider.overrideWithValue(Duration.zero),
    taskActionsProvider.overrideWithValue(actions ?? FakeTaskActions()),
    settingsRepositoryProvider.overrideWithValue(settings ?? FakeSettings()),
    if (prompt != null)
      notificationPromptControllerProvider.overrideWith(() => prompt),
  ];
}

/// Gives the test a phone-shaped screen.
///
/// [reduceMotion] turns on the system "reduce motion" setting, which removes
/// Ticky's entrance and squash and the list entrance fades.
void usePhoneScreen(WidgetTester tester, {bool reduceMotion = false}) {
  tester.view.physicalSize = const Size(1080, 3400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
}
