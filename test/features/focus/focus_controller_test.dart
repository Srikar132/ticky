import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

const today = '2026-11-08';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var now = DateTime(2026, 11, 8, 10);

  setUp(() {
    now = DateTime(2026, 11, 8, 10);
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        focusSaveDelayProvider.overrideWithValue(
          const Duration(milliseconds: 30),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seed(String key, String body) async {
    final saved = now;
    now = DateTime.parse('${key}T10:00:00');
    await container.read(focusRepositoryProvider).save(key, body);
    now = saved;
  }

  Future<FocusDocController> open([String key = today]) async {
    // Riverpod 3 pauses a provider nobody listens to.
    container.listen(focusDocProvider(key), (_, _) {});
    await container.read(focusDocProvider(key).future);
    return container.read(focusDocProvider(key).notifier);
  }

  FocusDocState doc([String key = today]) =>
      container.read(focusDocProvider(key)).requireValue;

  Future<String> saved([String key = today]) =>
      container.read(focusRepositoryProvider).getBody(key);

  Future<void> pause() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  group('loading', () {
    test('an empty day opens as one empty line', () async {
      await open();
      expect(doc().blocks, hasLength(1));
      expect(doc().isBlank, isTrue);
    });

    test('a saved day opens with its blocks', () async {
      await seed(today, '- [ ] graphs\n- [x] trees');
      await open();
      expect(doc().blocks.map((b) => (b.type, b.text, b.checked)), [
        (FocusBlockType.todo, 'graphs', false),
        (FocusBlockType.todo, 'trees', true),
      ]);
      expect(doc().progress.done, 1);
    });
  });

  group('saving', () {
    test('typing is saved after a short pause, as markdown', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.onTextChanged(id, '[] ');
      controller.onTextChanged(id, 'DSA graphs');
      expect(await saved(), '', reason: 'not yet, still debouncing');

      await pause();
      expect(await saved(), '- [ ] DSA graphs');
    });

    test('flush saves at once', () async {
      final controller = await open();
      controller.onTextChanged(doc().blocks.single.id, 'hello');
      await controller.flush();
      expect(await saved(), 'hello');
    });

    test('ticking a goal is saved', () async {
      await seed(today, '- [ ] graphs');
      final controller = await open();
      controller.toggleTodo(doc().blocks.single.id);
      await controller.flush();
      expect(await saved(), '- [x] graphs');
    });

    test('clearing everything removes the day', () async {
      await seed(today, 'something');
      final controller = await open();
      controller.onTextChanged(doc().blocks.single.id, '');
      await controller.flush();
      expect(await db.select(db.dayNotes).get(), isEmpty);
    });

    test('closing the notebook saves an edit still waiting', () async {
      final key = today;
      container.listen(focusDocProvider(key), (_, _) {}).close();
      final subscription = container.listen(focusDocProvider(key), (_, _) {});
      await container.read(focusDocProvider(key).future);
      container
          .read(focusDocProvider(key).notifier)
          .onTextChanged(doc().blocks.single.id, 'last words');

      subscription.close();
      container.invalidate(focusDocProvider(key));
      await pause();
      expect(await saved(), 'last words');
    });

    test('a failed save is retried on the next flush', () async {
      final controller = await open();
      controller.onTextChanged(doc().blocks.single.id, 'x');
      // A day that became read-only makes the save fail.
      now = DateTime(2026, 11, 10, 9);
      await controller.flush();
      expect(await db.select(db.dayNotes).get(), isEmpty);

      now = DateTime(2026, 11, 8, 11);
      await controller.flush();
      expect(await saved(), 'x');
    });

    test('edits are written in order', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.onTextChanged(id, 'one');
      await controller.flush();
      controller.onTextChanged(id, 'two');
      await controller.flush();
      expect(await saved(), 'two');
    });
  });

  group('editing state', () {
    test('Enter in a goal adds a goal and asks for the cursor there', () async {
      await seed(today, '- [ ] graphs');
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.onTextChanged(id, 'graphs\n', cursor: 7);

      expect(doc().blocks, hasLength(2));
      expect(doc().focus?.id, doc().blocks[1].id);
      expect(doc().focusSerial, 1);
    });

    test('plain typing does not ask for a cursor move', () async {
      final controller = await open();
      controller.onTextChanged(doc().blocks.single.id, 'abc');
      expect(doc().focusSerial, 0);
    });

    test('setFocused tracks the line for the toolbar', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.setFocused(id);
      expect(doc().focusedBlock?.id, id);
      controller.toggleType(id, FocusBlockType.todo);
      expect(doc().focusedBlock?.type, FocusBlockType.todo);
    });

    test('edits before the notebook has loaded are ignored', () async {
      container.listen(focusDocProvider(today), (_, _) {});
      final controller = container.read(focusDocProvider(today).notifier);
      controller.onTextChanged(1, 'too early');
      await container.read(focusDocProvider(today).future);
      expect(doc().isBlank, isTrue);
    });
  });

  group('bring yesterday over', () {
    test('no earlier note means no offer', () async {
      await open();
      expect(doc().offer, isNull);
    });

    test('offers the last written day with its numbers', () async {
      await seed(
        '2026-11-07',
        '- [x] graphs\n- [ ] trees\n- [ ] spring\nnotes',
      );
      await open();
      final offer = doc().offer!;
      expect(offer.sourceDateKey, '2026-11-07');
      expect(offer.goals, 3);
      expect(offer.unfinished, 2);
      expect(offer.hasMixedProgress, isTrue);
    });

    test('is not offered when today already has something', () async {
      await seed('2026-11-07', '- [ ] a');
      await seed(today, 'already writing');
      await open();
      expect(doc().offer, isNull);
    });

    test('copy all brings everything, unticked, and saves it', () async {
      await seed('2026-11-07', '- [x] graphs\n- [ ] trees');
      final controller = await open();
      await controller.acceptOffer(unfinishedOnly: false);

      expect(doc().offer, isNull);
      expect(doc().blocks.map((b) => (b.text, b.checked)), [
        ('graphs', false),
        ('trees', false),
      ]);
      await controller.flush();
      expect(await saved(), '- [ ] graphs\n- [ ] trees');
    });

    test('unfinished only leaves the done goals behind', () async {
      await seed('2026-11-07', '- [x] graphs\n- [ ] trees');
      final controller = await open();
      await controller.acceptOffer(unfinishedOnly: true);
      expect(doc().blocks.map((b) => b.text), ['trees']);
    });

    test('yesterday itself is never changed', () async {
      await seed('2026-11-07', '- [x] graphs\n- [ ] trees');
      final controller = await open();
      await controller.acceptOffer(unfinishedOnly: true);
      await controller.flush();
      expect(await saved('2026-11-07'), '- [x] graphs\n- [ ] trees');
    });

    test(
      'start fresh keeps today empty and is not asked again today',
      () async {
        await seed('2026-11-07', '- [ ] trees');
        final controller = await open();
        await controller.declineOffer();

        expect(doc().offer, isNull);
        expect(doc().isBlank, isTrue);
        expect(
          await container
              .read(settingsRepositoryProvider)
              .getFocusCarryAnsweredDateKey(),
          today,
        );

        // Close and reopen: still no question today.
        container.invalidate(focusDocProvider(today));
        await open();
        expect(doc().offer, isNull);
      },
    );

    test('asked again on the next day', () async {
      await seed('2026-11-07', '- [ ] trees');
      final controller = await open();
      await controller.declineOffer();

      now = DateTime(2026, 11, 9, 9);
      await seed('2026-11-08', '- [ ] spring');
      await open('2026-11-09');
      expect(doc('2026-11-09').offer?.sourceDateKey, '2026-11-08');
    });

    test('works when the last note is a few days old', () async {
      await seed('2026-11-05', '- [ ] trees');
      await open();
      expect(doc().offer?.sourceDateKey, '2026-11-05');
    });
  });
}
