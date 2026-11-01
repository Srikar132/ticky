import 'dart:convert';

import 'package:ticky/core/notifications/notification_ids.dart';

/// Everything needed to schedule one notification.
///
/// [when] is a floating local wall-clock time. The gateway turns it into a
/// timezone-aware instant using the device's current timezone.
class PlannedNotification {
  PlannedNotification({
    required this.routineId,
    required this.dateKey,
    required this.kind,
    required this.when,
    required this.title,
    required this.body,
    required this.alarm,
    required this.sound,
    required this.vibration,
    required this.exact,
    required this.timezone,
  }) : id = NotificationIds.encode(
         routineId: routineId,
         dateKey: dateKey,
         kind: kind,
       );

  final int id;
  final int routineId;
  final String dateKey;
  final ReminderKind kind;
  final DateTime when;
  final String title;
  final String body;

  /// Alarm-style: louder, uses the alarm audio stream and exact timing.
  final bool alarm;
  final bool sound;
  final bool vibration;

  /// Whether exact alarms are permitted right now.
  final bool exact;
  final String timezone;

  /// Stored with the pending notification. Carries the routine and date so a
  /// tap can open the task, plus a fingerprint of everything that affects the
  /// notification, so unchanged notifications are not rescheduled.
  late final String payload = ReminderPayload(
    routineId: routineId,
    dateKey: dateKey,
    fingerprint: _fingerprint(),
  ).encode();

  String _fingerprint() => fnv1a(
    '$id|${when.toIso8601String()}|$title|$body|$alarm|$sound|$vibration|'
    '$exact|$timezone|v$notificationFormatVersion',
  );
}

/// Bump when how a notification looks or sounds changes without its content
/// changing (new channel, new sound), so already scheduled ones are replaced.
/// 2: alarms ring with the alarm tone on their own channel.
const notificationFormatVersion = 2;

/// Payload format: `ticky1|<routineId>|<dateKey>|<fingerprint>`.
class ReminderPayload {
  const ReminderPayload({
    required this.routineId,
    required this.dateKey,
    required this.fingerprint,
  });

  final int routineId;
  final String dateKey;
  final String fingerprint;

  String encode() => 'ticky1|$routineId|$dateKey|$fingerprint';

  static ReminderPayload? parse(String? raw) {
    final parts = raw?.split('|');
    if (parts == null || parts.length != 4 || parts[0] != 'ticky1') {
      return null;
    }
    final routineId = int.tryParse(parts[1]);
    if (routineId == null) return null;
    return ReminderPayload(
      routineId: routineId,
      dateKey: parts[2],
      fingerprint: parts[3],
    );
  }
}

/// Stable 32-bit FNV-1a hash as hex. (`String.hashCode` is not stable across
/// runs, so it cannot be persisted.)
String fnv1a(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
