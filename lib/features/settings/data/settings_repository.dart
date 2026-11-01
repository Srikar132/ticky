import 'package:ticky/core/database/app_database.dart';
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
