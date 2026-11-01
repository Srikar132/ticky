import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/notifications/notification_ids.dart';
import 'package:ticky/core/notifications/planned_notification.dart';

void main() {
  group('NotificationIds', () {
    test('round-trips routine, date and kind', () {
      for (final kind in ReminderKind.values) {
        final id = NotificationIds.encode(
          routineId: 123,
          dateKey: '2026-11-02',
          kind: kind,
        );

        final decoded = NotificationIds.decode(id)!;
        expect(decoded.routineId, 123);
        expect(decoded.dateKey, '2026-11-02');
        expect(decoded.kind, kind);
      }
    });

    test('ids are positive 31-bit and unique per routine, date and kind', () {
      final ids = <int>{};
      for (final routineId in [1, 2, 300, NotificationIds.maxRoutineId]) {
        for (final dateKey in ['2020-01-01', '2026-11-02', '2026-11-03']) {
          for (final kind in ReminderKind.values) {
            final id = NotificationIds.encode(
              routineId: routineId,
              dateKey: dateKey,
              kind: kind,
            );
            expect(id, inInclusiveRange(1, 0x7FFFFFFF));
            expect(ids.add(id), isTrue, reason: '$routineId $dateKey $kind');
          }
        }
      }
    });

    test('handles month ends and leap days', () {
      for (final dateKey in ['2028-02-29', '2026-12-31', '2027-01-01']) {
        final id = NotificationIds.encode(
          routineId: 5,
          dateKey: dateKey,
          kind: ReminderKind.reminder,
        );
        expect(NotificationIds.decode(id)!.dateKey, dateKey);
      }
    });

    test('rejects values that do not fit', () {
      expect(
        () => NotificationIds.encode(
          routineId: 0,
          dateKey: '2026-11-02',
          kind: ReminderKind.reminder,
        ),
        throwsRangeError,
      );
      expect(
        () => NotificationIds.encode(
          routineId: NotificationIds.maxRoutineId + 1,
          dateKey: '2026-11-02',
          kind: ReminderKind.reminder,
        ),
        throwsRangeError,
      );
      expect(
        () => NotificationIds.encode(
          routineId: 1,
          dateKey: '2019-12-31',
          kind: ReminderKind.reminder,
        ),
        throwsRangeError,
      );
    });

    test('decode ignores ids this app did not create', () {
      expect(NotificationIds.decode(0), isNull);
      expect(NotificationIds.decode(-5), isNull);
      expect(NotificationIds.decode(0x0000C000 | 0x10000), isNull); // kind 3
    });
  });

  group('ReminderPayload', () {
    test('round-trips', () {
      const payload = ReminderPayload(
        routineId: 7,
        dateKey: '2026-11-02',
        fingerprint: 'abc12345',
      );

      final parsed = ReminderPayload.parse(payload.encode())!;

      expect(parsed.routineId, 7);
      expect(parsed.dateKey, '2026-11-02');
      expect(parsed.fingerprint, 'abc12345');
    });

    test('rejects foreign payloads', () {
      expect(ReminderPayload.parse(null), isNull);
      expect(ReminderPayload.parse('hello'), isNull);
      expect(ReminderPayload.parse('other|1|2026-11-02|x'), isNull);
      expect(ReminderPayload.parse('ticky1|x|2026-11-02|y'), isNull);
    });

    test('fnv1a is stable', () {
      expect(fnv1a(''), '811c9dc5');
      expect(fnv1a('a'), 'e40c292c');
      expect(fnv1a('ticky'), fnv1a('ticky'));
      expect(fnv1a('ticky'), isNot(fnv1a('Ticky')));
    });
  });
}
