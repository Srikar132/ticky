import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/notifications/android_channel_spec.dart';
import 'package:ticky/core/notifications/notification_ids.dart';
import 'package:ticky/core/notifications/planned_notification.dart';

PlannedNotification notification({
  bool alarm = false,
  bool sound = true,
  bool vibration = true,
}) {
  return PlannedNotification(
    routineId: 1,
    dateKey: '2026-11-02',
    kind: ReminderKind.reminder,
    when: DateTime(2026, 11, 2, 9),
    title: 'Drink water',
    body: 'Now',
    alarm: alarm,
    sound: sound,
    vibration: vibration,
    exact: true,
    timezone: 'Asia/Kolkata',
  );
}

void main() {
  group('alarms', () {
    test('ring with the phone alarm tone, repeating, then stop', () {
      final spec = AndroidChannelSpec.forNotification(
        notification(alarm: true),
      );

      expect(spec.soundUri, alarmSoundUri);
      expect(spec.soundUri, 'content://settings/system/alarm_alert');
      expect(spec.insistent, isTrue);
      expect(spec.timeout, alarmRingDuration);
      expect(spec.name, 'Task alarms');
    });

    test('with sound off they stay silent and do not repeat', () {
      final spec = AndroidChannelSpec.forNotification(
        notification(alarm: true, sound: false),
      );

      expect(spec.soundUri, isNull);
      expect(spec.insistent, isFalse);
      expect(spec.timeout, isNull);
    });

    test('use a channel that old installs never created', () {
      for (final sound in [true, false]) {
        for (final vibration in [true, false]) {
          final id = AndroidChannelSpec.forNotification(
            notification(alarm: true, sound: sound, vibration: vibration),
          ).id;
          expect(legacyChannelIds, isNot(contains(id)));
        }
      }
    });
  });

  group('reminders', () {
    test('keep the default notification tone and play once', () {
      final spec = AndroidChannelSpec.forNotification(notification());

      expect(spec.soundUri, isNull, reason: 'channel default tone');
      expect(spec.insistent, isFalse);
      expect(spec.timeout, isNull);
      expect(spec.id, 'ticky_reminder_s1v1');
    });
  });

  test('each sound and vibration mix gets its own channel', () {
    final ids = {
      for (final alarm in [true, false])
        for (final sound in [true, false])
          for (final vibration in [true, false])
            AndroidChannelSpec.forNotification(
              notification(alarm: alarm, sound: sound, vibration: vibration),
            ).id,
    };
    expect(ids, hasLength(8));
  });

  test('every legacy channel is an old alarm channel', () {
    expect(legacyChannelIds, hasLength(4));
    expect(
      legacyChannelIds.every((id) => id.startsWith('ticky_alarm_s')),
      isTrue,
    );
  });

  test('the payload is stable for equal input and differs with the sound', () {
    final first = notification(alarm: true).payload;

    expect(first, notification(alarm: true).payload);
    expect(first, isNot(notification(alarm: true, sound: false).payload));
  });
}
