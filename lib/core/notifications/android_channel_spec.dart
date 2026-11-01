import 'package:ticky/core/notifications/planned_notification.dart';

/// The phone's own alarm tone (`Settings.System.DEFAULT_ALARM_ALERT_URI`).
const alarmSoundUri = 'content://settings/system/alarm_alert';

/// How long an alarm rings if nobody reacts. The notification is removed after
/// this, which also stops the sound; the follow-up reminder (if enabled) and
/// the task on Home remain.
const alarmRingDuration = Duration(seconds: 60);

/// Android's `FLAG_INSISTENT`: repeat the sound until the notification is
/// dismissed, opened or removed.
const insistentFlag = 4;

/// Channels from before alarms had their own tone. Android keeps a channel's
/// sound forever once created, so these are deleted and replaced.
const legacyChannelIds = <String>[
  'ticky_alarm_s0v0',
  'ticky_alarm_s0v1',
  'ticky_alarm_s1v0',
  'ticky_alarm_s1v1',
];

/// How a notification should look and sound on Android, decided without any
/// plugin code so it can be tested.
///
/// Sound and vibration are channel properties that cannot change after the
/// channel exists, so every combination gets its own channel id. Bump the
/// alarm version in the id whenever alarm sound behaviour changes.
class AndroidChannelSpec {
  const AndroidChannelSpec._({
    required this.id,
    required this.name,
    required this.description,
    required this.alarm,
    required this.sound,
    required this.vibration,
  });

  factory AndroidChannelSpec.forNotification(PlannedNotification n) {
    final kind = n.alarm ? 'alarm_v2' : 'reminder';
    return AndroidChannelSpec._(
      id: 'ticky_${kind}_s${n.sound ? 1 : 0}v${n.vibration ? 1 : 0}',
      name: n.alarm ? 'Task alarms' : 'Task reminders',
      description: n.alarm
          ? 'Alarm-style reminders for your tasks'
          : 'Reminders for your daily tasks',
      alarm: n.alarm,
      sound: n.sound,
      vibration: n.vibration,
    );
  }

  final String id;
  final String name;
  final String description;
  final bool alarm;
  final bool sound;
  final bool vibration;

  /// Alarms ring with the alarm tone; reminders use the default notification
  /// tone (null).
  String? get soundUri => alarm && sound ? alarmSoundUri : null;

  /// Only audible alarms repeat their sound.
  bool get insistent => alarm && sound;

  Duration? get timeout => insistent ? alarmRingDuration : null;
}
