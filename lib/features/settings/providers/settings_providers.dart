import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/features/character/models/mascot_assets.dart';
import 'package:ticky/features/rewards/data/reward_repository.dart';
import 'package:ticky/features/rewards/models/shop_item.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/settings/data/settings_repository.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

/// Notification, sound, vibration and snooze preferences, live.
final notificationPrefsProvider = StreamProvider<NotificationPrefs>(
  (ref) => ref.watch(settingsRepositoryProvider).watchNotificationPrefs(),
);

/// What the phone currently allows. Invalidate it when the app resumes, since
/// the user may have changed it in system settings.
final notificationPermissionProvider =
    FutureProvider.autoDispose<NotificationPermissionStatus>(
      (ref) => ref.watch(notificationServiceProvider).getPermissionStatus(),
    );

/// Keys of the shop items that were bought.
final unlockedItemKeysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(rewardRepositoryProvider).watchUnlockedItemKeys(),
);

/// The shop item Ticky wears, or null for the plain default.
final equippedItemKeyProvider = StreamProvider<String?>(
  (ref) => ref.watch(settingsRepositoryProvider).watchEquippedMascotItem(),
);

/// The pose id Ticky shows while idle, or null. Only returns a pose that is
/// actually bought, so a stale setting cannot show an item for free.
final idlePoseProvider = Provider<String?>((ref) {
  final key = ref.watch(equippedItemKeyProvider).value;
  final owned = ref.watch(unlockedItemKeysProvider).value ?? const {};
  final item = shopItemFor(key);
  if (item == null || !owned.contains(item.key)) return null;
  return MascotAssets.poses.contains(item.pose) ? item.pose : null;
});

/// What the item shop can do. A seam for the UI, and for tests.
class ShopActions {
  ShopActions({
    required RewardRepository rewards,
    required SettingsRepository settings,
  }) : _rewards = rewards,
       _settings = settings;

  final RewardRepository _rewards;
  final SettingsRepository _settings;

  /// Buys [item] and puts it on Ticky straight away.
  ///
  /// Throws [InsufficientCoinsException] or [ItemAlreadyUnlockedException].
  Future<void> buy(ShopItem item) async {
    await _rewards.unlockItem(item.key, item.price);
    await _settings.setEquippedMascotItem(item.key);
  }

  /// Puts a bought item on Ticky, or the plain default with null.
  ///
  /// Throws [ItemNotOwnedException] for an item that was not bought.
  Future<void> equip(String? itemKey) async {
    if (itemKey != null &&
        !(await _rewards.getUnlockedItemKeys()).contains(itemKey)) {
      throw ItemNotOwnedException('$itemKey has not been bought');
    }
    await _settings.setEquippedMascotItem(itemKey);
  }
}

final shopActionsProvider = Provider<ShopActions>(
  (ref) => ShopActions(
    rewards: ref.watch(rewardRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);

/// What the notification settings can do. A seam for the UI, and for tests.
class SettingsActions {
  SettingsActions({
    required SettingsRepository settings,
    required NotificationService notifications,
  }) : _settings = settings,
       _notifications = notifications;

  final SettingsRepository _settings;
  final NotificationService _notifications;

  /// Turns reminders on or off. Reminders are re-synced by the coordinator
  /// when the setting changes.
  ///
  /// Returns true when the switch is on but the phone is not allowing
  /// notifications, so the screen should offer the permission sheet.
  Future<bool> setRemindersEnabled(bool enabled) async {
    await _settings.setNotificationsEnabled(enabled);
    if (!enabled) return false;
    try {
      return !(await _notifications.getPermissionStatus()).notificationsAllowed;
    } on Exception {
      return false;
    }
  }

  Future<void> setSoundEnabled(bool enabled) =>
      _settings.setSoundEnabled(enabled);

  Future<void> setVibrationEnabled(bool enabled) =>
      _settings.setVibrationEnabled(enabled);

  Future<void> setFollowUpEnabled(bool enabled) =>
      _settings.setFollowUpEnabled(enabled);

  Future<void> setDefaultSnoozeMinutes(int minutes) =>
      _settings.setDefaultSnoozeMinutes(minutes);
}

final settingsActionsProvider = Provider<SettingsActions>(
  (ref) => SettingsActions(
    settings: ref.watch(settingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);
