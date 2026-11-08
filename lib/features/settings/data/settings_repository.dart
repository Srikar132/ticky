import 'package:flutter/material.dart' show ThemeMode;
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/features/settings/models/feedback_prefs.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';

/// Typed access to `app_settings`. Add one getter/setter pair per key.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _lastReconciledDateKey = 'lastReconciledDateKey';
  static const _notificationsEnabled = 'notificationsEnabled';
  static const _soundEnabled = 'soundEnabled';
  static const _vibrationEnabled = 'vibrationEnabled';
  static const _followUpEnabled = 'followUpEnabled';
  static const _defaultSnoozeMinutes = 'defaultSnoozeMinutes';
  static const _notificationPromptDismissedAt = 'notificationPromptDismissedAt';
  static const _equippedMascotItem = 'equippedMascotItem';
  static const _themeMode = 'themeMode';
  static const _hapticsEnabled = 'hapticsEnabled';
  static const _soundEffectsEnabled = 'soundEffectsEnabled';
  static const _focusCarryAnsweredDateKey = 'focusCarryAnsweredDateKey';

  /// Local date (`yyyy-MM-dd`) of the last completed daily reconcile.
  Future<String?> getLastReconciledDateKey() => _read(_lastReconciledDateKey);

  Future<void> setLastReconciledDateKey(String dateKey) =>
      _write(_lastReconciledDateKey, dateKey);

  /// When the user last closed the "turn on reminders" sheet without turning
  /// them on. Null if never.
  Future<DateTime?> getNotificationPromptDismissedAt() async {
    final raw = await _read(_notificationPromptDismissedAt);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> setNotificationPromptDismissedAt(DateTime at) =>
      _write(_notificationPromptDismissedAt, at.toUtc().toIso8601String());

  /// The day the user last answered "bring yesterday's focus over?" (copied
  /// it or chose a fresh page), so the question is asked once a day.
  Future<String?> getFocusCarryAnsweredDateKey() =>
      _read(_focusCarryAnsweredDateKey);

  Future<void> setFocusCarryAnsweredDateKey(String dateKey) =>
      _write(_focusCarryAnsweredDateKey, dateKey);

  Future<NotificationPrefs> getNotificationPrefs() async {
    final rows = await _db.select(_db.appSettings).get();
    return _prefsFrom({for (final row in rows) row.key: row.value});
  }

  /// The preferences, live. Emits again whenever any setting changes.
  Stream<NotificationPrefs> watchNotificationPrefs() {
    return _db
        .select(_db.appSettings)
        .watch()
        .map(
          (rows) => _prefsFrom({for (final row in rows) row.key: row.value}),
        );
  }

  NotificationPrefs _prefsFrom(Map<String, String> values) {
    bool flag(String key) => values[key] != 'false'; // default: on
    final snooze = int.tryParse(values[_defaultSnoozeMinutes] ?? '');
    return NotificationPrefs(
      notificationsEnabled: flag(_notificationsEnabled),
      soundEnabled: flag(_soundEnabled),
      vibrationEnabled: flag(_vibrationEnabled),
      followUpEnabled: flag(_followUpEnabled),
      defaultSnoozeMinutes: (snooze != null && snooze > 0)
          ? snooze
          : NotificationPrefs.defaultSnooze,
    );
  }

  Future<void> setNotificationsEnabled(bool value) =>
      _write(_notificationsEnabled, '$value');

  Future<void> setSoundEnabled(bool value) => _write(_soundEnabled, '$value');

  Future<void> setVibrationEnabled(bool value) =>
      _write(_vibrationEnabled, '$value');

  Future<void> setFollowUpEnabled(bool value) =>
      _write(_followUpEnabled, '$value');

  Future<void> setDefaultSnoozeMinutes(int minutes) {
    if (minutes <= 0) {
      throw ArgumentError.value(minutes, 'minutes', 'must be > 0');
    }
    return _write(_defaultSnoozeMinutes, '$minutes');
  }

  /// Key of the shop item Ticky wears, or null for the plain default.
  Future<String?> getEquippedMascotItem() => _read(_equippedMascotItem);

  Stream<String?> watchEquippedMascotItem() {
    return (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_equippedMascotItem)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// Null puts Ticky back to the plain default.
  Future<void> setEquippedMascotItem(String? itemKey) async {
    if (itemKey == null) {
      await (_db.delete(
        _db.appSettings,
      )..where((s) => s.key.equals(_equippedMascotItem))).go();
    } else {
      await _write(_equippedMascotItem, itemKey);
    }
  }

  /// Ticky's own haptics and sound effects. Both default to on.
  Future<FeedbackPrefs> getFeedbackPrefs() async {
    final rows = await _db.select(_db.appSettings).get();
    return _feedbackFrom({for (final row in rows) row.key: row.value});
  }

  Stream<FeedbackPrefs> watchFeedbackPrefs() {
    return _db
        .select(_db.appSettings)
        .watch()
        .map((rows) => _feedbackFrom({for (final r in rows) r.key: r.value}))
        .distinct();
  }

  FeedbackPrefs _feedbackFrom(Map<String, String> values) => FeedbackPrefs(
    haptics: values[_hapticsEnabled] != 'false',
    sounds: values[_soundEffectsEnabled] != 'false',
  );

  Future<void> setHapticsEnabled(bool value) =>
      _write(_hapticsEnabled, '$value');

  Future<void> setSoundEffectsEnabled(bool value) =>
      _write(_soundEffectsEnabled, '$value');

  /// How the app picks its theme. Defaults to following the system.
  Future<ThemeMode> getThemeMode() async =>
      _themeModeFrom(await _read(_themeMode));

  /// Stored by name: `system`, `light` or `dark`.
  Future<void> setThemeMode(ThemeMode mode) => _write(_themeMode, mode.name);

  static ThemeMode _themeModeFrom(String? raw) {
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    return ThemeMode.system;
  }

  Future<String?> _read(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }
}
