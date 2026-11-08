import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/features/focus/data/focus_repository.dart';

void main() {
  late AppDatabase db;
  late FocusRepository repo;
  var now = DateTime(2026, 11, 8, 10);

  setUp(() {
    now = DateTime(2026, 11, 8, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = FocusRepository(db, () => now);
  });

  tearDown(() => db.close());

  test('an unwritten day reads as empty', () async {
    expect(await repo.getBody('2026-11-08'), '');
    expect(await repo.watchBody('2026-11-08').first, '');
  });

  test('saves and reads back, and overwriting keeps one row', () async {
    await repo.save('2026-11-08', '- [ ] graphs');
    await repo.save('2026-11-08', '- [x] graphs');
    expect(await repo.getBody('2026-11-08'), '- [x] graphs');
    expect(await db.select(db.dayNotes).get(), hasLength(1));
  });

  test('a blank body removes the row', () async {
    await repo.save('2026-11-08', 'something');
    await repo.save('2026-11-08', '  \n \n');
    expect(await db.select(db.dayNotes).get(), isEmpty);
  });

  test('stores the save time in UTC', () async {
    await repo.save('2026-11-08', 'x');
    final row = await db.select(db.dayNotes).getSingle();
    expect(row.updatedAt.toUtc(), now.toUtc());
  });

  group('who can write', () {
    test('only today, past days are read-only', () async {
      await expectLater(
        repo.save('2026-11-07', 'x'),
        throwsA(isA<ReadOnlyDayException>()),
      );
      await expectLater(
        repo.save('2026-11-09', 'x'),
        throwsA(isA<ReadOnlyDayException>()),
      );
      expect(await db.select(db.dayNotes).get(), isEmpty);
    });

    test('yesterday stays writable for two hours after midnight', () async {
      now = DateTime(2026, 11, 9, 1, 59);
      await repo.save('2026-11-08', 'last edit');
      expect(await repo.getBody('2026-11-08'), 'last edit');

      now = DateTime(2026, 11, 9, 2);
      await expectLater(
        repo.save('2026-11-08', 'too late'),
        throwsA(isA<ReadOnlyDayException>()),
      );
      expect(await repo.getBody('2026-11-08'), 'last edit');
    });

    test('a blank save of a past day is also refused', () async {
      await repo.save('2026-11-08', 'keep me');
      now = DateTime(2026, 11, 10, 9);
      await expectLater(
        repo.save('2026-11-08', ''),
        throwsA(isA<ReadOnlyDayException>()),
      );
      expect(await repo.getBody('2026-11-08'), 'keep me');
    });
  });

  group('latestBefore', () {
    Future<void> write(String key) async {
      final saved = now;
      now = DateTime.parse('${key}T10:00:00');
      await repo.save(key, 'note $key');
      now = saved;
    }

    test('finds the most recent earlier day', () async {
      await write('2026-11-03');
      await write('2026-11-06');
      final note = await repo.latestBefore('2026-11-08');
      expect(note?.dateKey, '2026-11-06');
    });

    test('ignores today and later days', () async {
      await write('2026-11-08');
      await write('2026-11-09');
      expect(await repo.latestBefore('2026-11-08'), isNull);
    });

    test('ignores days older than the lookback window', () async {
      await write('2026-10-30');
      expect(await repo.latestBefore('2026-11-08'), isNull);
      await write('2026-11-01');
      expect((await repo.latestBefore('2026-11-08'))?.dateKey, '2026-11-01');
    });
  });

  test('daysWithNotes lists only days that have one', () async {
    await repo.save('2026-11-08', 'x');
    expect(await repo.daysWithNotes(['2026-11-07', '2026-11-08']), {
      '2026-11-08',
    });
  });
}
