import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_editing.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';

const today = '2026-11-08';
const todo = FocusBlockType.todo;
const text = FocusBlockType.text;

FocusBlock b(FocusBlockType type, String body, {bool checked = false}) =>
    FocusBlock.create(type: type, text: body, checked: checked);

void main() {
  group('moveBlock', () {
    test('swaps with the neighbour', () {
      final blocks = [b(text, 'a'), b(text, 'b'), b(text, 'c')];
      expect(moveBlock(blocks, blocks[1].id, -1).map((x) => x.text), [
        'b',
        'a',
        'c',
      ]);
      expect(moveBlock(blocks, blocks[1].id, 1).map((x) => x.text), [
        'a',
        'c',
        'b',
      ]);
    });

    test('at the edge nothing changes', () {
      final blocks = [b(text, 'a'), b(text, 'b')];
      expect(moveBlock(blocks, blocks.first.id, -1), same(blocks));
      expect(moveBlock(blocks, blocks.last.id, 1), same(blocks));
      expect(moveBlock(blocks, -1, 1), same(blocks));
    });

    test('keeps the block and its id', () {
      final blocks = [b(todo, 'a', checked: true), b(text, 'b')];
      final moved = moveBlock(blocks, blocks.first.id, 1);
      expect(moved.last.id, blocks.first.id);
      expect(moved.last.checked, isTrue);
    });
  });

  group('removeDoneGoals', () {
    test('removes ticked goals and keeps everything else', () {
      final blocks = [
        b(todo, 'done', checked: true),
        b(todo, 'open'),
        b(text, 'note'),
      ];
      expect(removeDoneGoals(blocks).map((x) => x.text), ['open', 'note']);
    });

    test('returns the same list when nothing is done', () {
      final blocks = [b(todo, 'open'), b(text, 'note')];
      expect(removeDoneGoals(blocks), same(blocks));
    });

    test('never leaves the page empty', () {
      final result = removeDoneGoals([b(todo, 'done', checked: true)]);
      expect(result, hasLength(1));
      expect(result.single.type, text);
    });
  });

  group('undo', () {
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

    Future<FocusDocController> open() async {
      container.listen(focusDocProvider(today), (_, _) {});
      await container.read(focusDocProvider(today).future);
      return container.read(focusDocProvider(today).notifier);
    }

    FocusDocState doc() => container.read(focusDocProvider(today)).requireValue;

    Future<void> seed(String body) =>
        container.read(focusRepositoryProvider).save(today, body);

    test('nothing to undo on a fresh page', () async {
      final controller = await open();
      expect(doc().canUndo, isFalse);
      controller.undo();
      expect(doc().isBlank, isTrue);
    });

    test('takes back a deleted line', () async {
      await seed('one\ntwo\nthree');
      final controller = await open();
      final id = doc().blocks[1].id;
      controller.deleteBlock(id);
      expect(doc().blocks.map((x) => x.text), ['one', 'three']);
      expect(doc().canUndo, isTrue);

      controller.undo();
      expect(doc().blocks.map((x) => x.text), ['one', 'two', 'three']);
      expect(doc().blocks[1].id, id, reason: 'same line, same id');
      expect(doc().canUndo, isFalse);
    });

    test(
      'takes back a tick, a move and a type change, one at a time',
      () async {
        await seed('- [ ] a\n- [ ] b');
        final controller = await open();
        final a = doc().blocks[0].id;
        final bId = doc().blocks[1].id;

        controller.toggleTodo(a);
        controller.moveBlock(a, 1);
        controller.toggleType(bId, FocusBlockType.heading);

        controller.undo();
        expect(doc().blocks[0].type, todo, reason: 'type change undone');
        controller.undo();
        expect(doc().blocks.map((x) => x.text), [
          'a',
          'b',
        ], reason: 'move undone');
        expect(doc().blocks[0].checked, isTrue);
        controller.undo();
        expect(doc().blocks[0].checked, isFalse, reason: 'tick undone');
        expect(doc().canUndo, isFalse);
      },
    );

    test('a burst of typing is one undo step', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      for (final part in ['h', 'he', 'hel', 'hell', 'hello']) {
        controller.onTextChanged(id, part);
        now = now.add(const Duration(milliseconds: 200));
      }
      expect(doc().blocks.single.text, 'hello');

      controller.undo();
      expect(doc().blocks.single.text, '');
      expect(doc().canUndo, isFalse);
    });

    test('typing after a pause is a separate step', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.onTextChanged(id, 'first');
      now = now.add(const Duration(seconds: 5));
      controller.onTextChanged(id, 'first second');

      controller.undo();
      expect(doc().blocks.single.text, 'first');
      controller.undo();
      expect(doc().blocks.single.text, '');
    });

    test('a structural edit between typing starts a new step', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.onTextChanged(id, 'abc');
      controller.toggleType(id, FocusBlockType.heading);
      controller.onTextChanged(id, 'abcd');

      controller.undo();
      expect(doc().blocks.single.text, 'abc');
      expect(doc().blocks.single.type, FocusBlockType.heading);
      controller.undo();
      expect(doc().blocks.single.type, text);
    });

    test('undo is saved too', () async {
      await seed('one\ntwo');
      final controller = await open();
      controller.deleteBlock(doc().blocks[1].id);
      await controller.flush();
      expect(
        await container.read(focusRepositoryProvider).getBody(today),
        'one',
      );

      controller.undo();
      await controller.flush();
      expect(
        await container.read(focusRepositoryProvider).getBody(today),
        'one\ntwo',
      );
    });

    test('does not remember edits that changed nothing', () async {
      await seed('- [ ] a');
      final controller = await open();
      final id = doc().blocks.single.id;
      controller.clearDone();
      controller.moveBlock(id, 1);
      controller.moveBlock(id, -1);
      controller.onTextChanged(id, 'a');
      expect(doc().canUndo, isFalse);
    });

    test('clearing done goals can be undone', () async {
      await seed('- [x] a\n- [ ] b\n- [x] c');
      final controller = await open();
      controller.clearDone();
      expect(doc().blocks.map((x) => x.text), ['b']);
      controller.undo();
      expect(doc().blocks.map((x) => x.text), ['a', 'b', 'c']);
      expect(doc().blocks[0].checked, isTrue);
    });

    test('bringing yesterday over can be undone', () async {
      // Yesterday's page.
      now = DateTime(2026, 11, 7, 10);
      await container
          .read(focusRepositoryProvider)
          .save('2026-11-07', '- [ ] trees');
      now = DateTime(2026, 11, 8, 10);

      final controller = await open();
      await controller.acceptOffer(unfinishedOnly: false);
      expect(doc().blocks.single.text, 'trees');

      controller.undo();
      expect(doc().isBlank, isTrue);
    });

    test('the history is capped', () async {
      final controller = await open();
      final id = doc().blocks.single.id;
      for (var i = 0; i < 150; i++) {
        controller.toggleType(
          id,
          i.isEven ? FocusBlockType.heading : FocusBlockType.bullet,
        );
      }
      var undone = 0;
      while (doc().canUndo) {
        controller.undo();
        undone++;
      }
      expect(undone, 100);
    });

    test('markdown is what gets copied', () async {
      await seed('# Plan\n- [x] a\n- [ ] b');
      final controller = await open();
      expect(controller.markdown, '# Plan\n- [x] a\n- [ ] b');
    });
  });
}
