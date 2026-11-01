import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import '../../support/test_env.dart';

// 2026-11-02 is a Monday.
void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('daily generation', () {
    test('creates records only for routines scheduled today', () async {
      final monday = await env.addRoutine(title: 'Mon', repeatDays: 1);
      await env.addRoutine(title: 'Tue', repeatDays: 2);
      await env.addRoutine(title: 'Anytime', reminderMinutes: null);

      await env.reconciler.reconcile(env.now);

      final records = await env.allRecords();
      expect(records.map((r) => r.titleSnapshot), ['Mon', 'Anytime']);
      expect(records.every((r) => r.dateKey == '2026-11-02'), isTrue);
      expect(records.first.routineTaskId, monday);
      expect(records.first.scheduledMinutes, 480);
      expect(records.last.scheduledMinutes, isNull);
    });

    test('skips paused and archived routines', () async {
      final paused = await env.addRoutine(title: 'Paused');
      final archived = await env.addRoutine(title: 'Archived');
      await env.addRoutine(title: 'Active');
      await env.routines.setEnabled(paused, false);
      await env.routines.archive(archived);

      await env.reconciler.reconcile(env.now);

      final records = await env.allRecords();
      expect(records.map((r) => r.titleSnapshot), ['Active']);
    });

    test('is idempotent', () async {
      await env.addRoutine();

      await env.reconciler.reconcile(env.now);
      await env.reconciler.reconcile(env.now);
      await env.reconciler.reconcile(env.now);

      expect(await env.allRecords(), hasLength(1));
    });

    test('stores lastReconciledDateKey', () async {
      expect(await env.settings.getLastReconciledDateKey(), isNull);

      await env.reconciler.reconcile(env.now);

      expect(await env.settings.getLastReconciledDateKey(), '2026-11-02');
    });
  });

  group('rollover', () {
    test('turns yesterday pending into missed, keeps completed', () async {
      final done = await env.addRoutine(title: 'Done');
      final open = await env.addRoutine(title: 'Open');
      await env.reconciler.reconcile(env.now);
      final doneRecord = await env.recordFor(done, '2026-11-02');
      await env.records.setStatus(doneRecord.id, TaskStatus.completed);

      env.now = DateTime(2026, 11, 3, 7);
      await env.reconciler.reconcile(env.now);

      expect(
        (await env.recordFor(done, '2026-11-02')).status,
        TaskStatus.completed,
      );
      expect(
        (await env.recordFor(open, '2026-11-02')).status,
        TaskStatus.missed,
      );
      expect(
        (await env.recordFor(open, '2026-11-03')).status,
        TaskStatus.pending,
      );
    });

    test('backfills unused days as missed for scheduled days only', () async {
      // Monday-to-Friday style routine: Mon + Wed + Thu.
      final id = await env.addRoutine(repeatDays: 1 | 4 | 8);
      await env.reconciler.reconcile(env.now); // Mon

      env.now = DateTime(2026, 11, 6, 8); // Fri, app unused Tue-Thu
      await env.reconciler.reconcile(env.now);

      final records = await env.allRecords();
      expect(records.map((r) => (r.dateKey, r.status)), [
        ('2026-11-02', TaskStatus.missed),
        ('2026-11-04', TaskStatus.missed),
        ('2026-11-05', TaskStatus.missed),
      ]);
      expect(records.every((r) => r.routineTaskId == id), isTrue);
    });

    test('caps the backfill at 30 days', () async {
      await env.addRoutine();
      await env.reconciler.reconcile(env.now);

      env.now = DateTime(2026, 12, 31, 8); // 59 days later
      await env.reconciler.reconcile(env.now);

      final records = await env.allRecords();
      final missed = records.where((r) => r.status == TaskStatus.missed);
      // Original day (pending -> missed) + 30 backfilled days.
      expect(missed, hasLength(31));
      expect(records.first.dateKey, '2026-11-02');
      expect(records.where((r) => r.dateKey == '2026-12-01'), hasLength(1));
      expect(records.where((r) => r.dateKey == '2026-11-30'), isEmpty);
      expect(records.last.dateKey, '2026-12-31');
      expect(records.last.status, TaskStatus.pending);
    });

    test('does not backfill days before the routine existed', () async {
      await env.reconciler.reconcile(env.now); // Mon, no routines yet
      env.now = DateTime(2026, 11, 4, 8); // Wed
      final id = await env.addRoutine();

      env.now = DateTime(2026, 11, 5, 8); // Thu
      await env.reconciler.reconcile(env.now);

      final records = await env.allRecords();
      expect(records.map((r) => r.dateKey), ['2026-11-04', '2026-11-05']);
      expect(records.every((r) => r.routineTaskId == id), isTrue);
    });

    test('does not backfill days a routine was paused', () async {
      final id = await env.addRoutine();
      await env.reconciler.reconcile(env.now); // Mon
      env.now = DateTime(2026, 11, 3, 8);
      await env.reconciler.reconcile(env.now); // Tue, opened daily
      await env.routines.setEnabled(id, false);

      env.now = DateTime(2026, 11, 6, 8); // Fri
      await env.reconciler.reconcile(env.now);
      await env.routines.setEnabled(id, true);

      // Tue's pending record was dropped when the routine was paused that day;
      // Wed-Thu (app unused while paused) are not backfilled as missed.
      final records = await env.allRecords();
      expect(records.map((r) => r.dateKey), ['2026-11-02', '2026-11-06']);
    });
  });

  group('history and edits', () {
    test('editing a routine only rewrites today pending snapshot', () async {
      final id = await env.addRoutine(title: 'Drink water');
      await env.reconciler.reconcile(env.now);
      env.now = DateTime(2026, 11, 3, 8);
      await env.reconciler.reconcile(env.now);

      final routine = (await env.routines.getById(id))!;
      await env.routines.update(
        id,
        _draftFrom(routine, title: 'Hydrate', reminderMinutes: 600),
      );

      final yesterday = await env.recordFor(id, '2026-11-02');
      final today = await env.recordFor(id, '2026-11-03');
      expect(yesterday.titleSnapshot, 'Drink water');
      expect(yesterday.scheduledMinutes, 480);
      expect(today.titleSnapshot, 'Hydrate');
      expect(today.scheduledMinutes, 600);
    });

    test('editing leaves a completed record untouched', () async {
      final id = await env.addRoutine(title: 'Drink water');
      await env.reconciler.reconcile(env.now);
      final record = await env.recordFor(id, '2026-11-02');
      await env.records.setStatus(record.id, TaskStatus.completed);

      final routine = (await env.routines.getById(id))!;
      await env.routines.update(id, _draftFrom(routine, title: 'Hydrate'));

      expect(
        (await env.recordFor(id, '2026-11-02')).titleSnapshot,
        'Drink water',
      );
    });

    test('archiving drops today pending record but keeps history', () async {
      final id = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      env.now = DateTime(2026, 11, 3, 8);
      await env.reconciler.reconcile(env.now);

      await env.routines.archive(id);

      final records = await env.allRecords();
      expect(records.map((r) => (r.dateKey, r.status)), [
        ('2026-11-02', TaskStatus.missed),
      ]);
      expect(
        (await env.routines.getById(id))!.archivedAt,
        isNotNull,
        reason: 'archived, not deleted',
      );
    });

    test('creating a routine adds it to today immediately', () async {
      await env.reconciler.reconcile(env.now);

      await env.addRoutine(title: 'New');

      expect((await env.allRecords()).map((r) => r.titleSnapshot), ['New']);
    });
  });
}

RoutineDraft _draftFrom(
  RoutineTask routine, {
  String? title,
  int? reminderMinutes,
}) {
  return RoutineDraft(
    title: title ?? routine.title,
    categoryId: routine.categoryId,
    reminderMinutes: reminderMinutes ?? routine.reminderMinutes,
    repeatDays: routine.repeatDays,
    priority: routine.priority,
  );
}
