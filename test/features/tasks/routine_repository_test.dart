import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/features/categories/models/category_draft.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late int general;

  setUp(() async {
    env = TestEnv();
    general = await env.generalId();
  });
  tearDown(() => env.close());

  group('validation', () {
    test('rejects bad drafts', () {
      final bad = <RoutineDraft>[
        RoutineDraft(title: '   ', categoryId: general),
        RoutineDraft(title: 'x' * 81, categoryId: general),
        RoutineDraft(title: 'Alarm', categoryId: general, alarmEnabled: true),
        RoutineDraft(title: 'Time', categoryId: general, reminderMinutes: 1440),
        RoutineDraft(title: 'Days', categoryId: general, repeatDays: 0),
        RoutineDraft(title: 'Days', categoryId: general, repeatDays: 128),
        RoutineDraft(title: 'Dur', categoryId: general, durationMinutes: 0),
      ];

      for (final draft in bad) {
        expect(
          env.routines.create(draft),
          throwsA(isA<InvalidRoutineException>()),
          reason: draft.title,
        );
      }
    });

    test('rejects an unknown category', () {
      expect(
        env.routines.create(RoutineDraft(title: 'Orphan', categoryId: 9999)),
        throwsA(isA<InvalidRoutineException>()),
      );
    });

    test('accepts an alarm with a time and normalizes text', () async {
      final id = await env.routines.create(
        RoutineDraft(
          title: '  Stretch  ',
          categoryId: general,
          reminderMinutes: 450,
          alarmEnabled: true,
          description: '   ',
          customReminderMessage: ' Move! ',
        ),
      );

      final routine = (await env.routines.getById(id))!;
      expect(routine.title, 'Stretch');
      expect(routine.alarmEnabled, isTrue);
      expect(routine.description, isNull);
      expect(routine.customReminderMessage, 'Move!');
    });
  });

  group('lifecycle', () {
    test('new routines go to the end of the manual order', () async {
      final a = await env.addRoutine(title: 'A');
      final b = await env.addRoutine(title: 'B');

      final list = await env.routines.watchActive().first;

      expect(list.map((r) => r.id), [a, b]);
      expect(list.map((r) => r.sortOrder), [0, 1]);
    });

    test('archive hides the routine but keeps the row', () async {
      final id = await env.addRoutine();

      await env.routines.archive(id);

      expect(await env.routines.watchActive().first, isEmpty);
      expect(await env.routines.getById(id), isNotNull);
      expect(env.routines.archive(id), throwsA(isA<NotFoundException>()));
    });

    test(
      'restore brings an archived routine and its task back today',
      () async {
        final id = await env.addRoutine(title: 'Walk');
        await env.routines.archive(id);
        expect(await env.allRecords(), isEmpty, reason: 'pending one removed');

        await env.routines.restore(id);

        expect((await env.routines.watchActive().first).single.id, id);
        final records = await env.allRecords();
        expect(records, hasLength(1));
        expect(records.single.titleSnapshot, 'Walk');
      },
    );

    test('restore keeps what was already completed today', () async {
      final id = await env.addRoutine();
      final record = await env.recordFor(id, '2026-11-02');
      await env.records.setStatus(record.id, TaskStatus.completed);
      await env.routines.archive(id);
      await env.routines.restore(id);

      final records = await env.allRecords();
      expect(records, hasLength(1), reason: 'no duplicate');
      expect(records.single.status, TaskStatus.completed);
    });

    test('restore moves a routine out of a category archived since', () async {
      final categoryId = await env.categories.create(
        const CategoryDraft(
          title: 'Pets',
          iconKey: 'pets',
          colorValue: 0xFF7C8DB5,
        ),
      );
      final id = await env.routines.create(
        RoutineDraft(title: 'Feed', categoryId: categoryId),
      );
      await env.routines.archive(id);
      await env.categories.archive(categoryId);

      await env.routines.restore(id);

      expect((await env.routines.getById(id))!.categoryId, general);
    });

    test('restoring a missing routine fails', () {
      expect(env.routines.restore(42), throwsA(isA<NotFoundException>()));
    });

    test('restoring a routine that is not archived changes nothing', () async {
      final id = await env.addRoutine();
      final before = (await env.routines.getById(id))!;

      await env.routines.restore(id);

      expect((await env.routines.getById(id))!.updatedAt, before.updatedAt);
      expect(await env.allRecords(), hasLength(1));
    });

    test('update of a missing routine fails', () {
      expect(
        env.routines.update(
          42,
          RoutineDraft(title: 'Ghost', categoryId: general),
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'pausing removes today pending record, resuming restores it',
      () async {
        final id = await env.addRoutine();
        expect(await env.allRecords(), hasLength(1));

        await env.routines.setEnabled(id, false);
        expect(await env.allRecords(), isEmpty);

        await env.routines.setEnabled(id, true);
        expect(await env.allRecords(), hasLength(1));
      },
    );
  });
}
