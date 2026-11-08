import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_editing.dart';
import 'package:ticky/features/focus/models/focus_markdown.dart';

const text = FocusBlockType.text;
const todo = FocusBlockType.todo;
const bullet = FocusBlockType.bullet;
const heading = FocusBlockType.heading;

FocusBlock b(FocusBlockType type, String body, {bool checked = false}) =>
    FocusBlock.create(type: type, text: body, checked: checked);

List<(FocusBlockType, String, bool)> shapes(List<FocusBlock> blocks) => [
  for (final x in blocks) (x.type, x.text, x.checked),
];

void main() {
  group('typing shortcuts', () {
    test('"[] " turns a plain line into a to-do', () {
      final blocks = [b(text, '')];
      final result = applyTextChange(blocks, blocks[0].id, '[] ');
      expect(shapes(result.blocks), [(todo, '', false)]);
      expect(result.focus?.id, blocks[0].id);
      expect(result.focus?.offset, 0);
    });

    test('"- [ ] " and "[ ] " also work, "[x] " makes a done to-do', () {
      for (final typed in ['- [ ] ', '[ ] ']) {
        final blocks = [b(text, '')];
        expect(shapes(applyTextChange(blocks, blocks[0].id, typed).blocks), [
          (todo, '', false),
        ]);
      }
      final blocks = [b(text, '')];
      expect(shapes(applyTextChange(blocks, blocks[0].id, '[x] ').blocks), [
        (todo, '', true),
      ]);
    });

    test('"- " becomes a bullet and "# " a heading', () {
      var blocks = [b(text, '')];
      expect(shapes(applyTextChange(blocks, blocks[0].id, '- ').blocks), [
        (bullet, '', false),
      ]);
      blocks = [b(text, '')];
      expect(shapes(applyTextChange(blocks, blocks[0].id, '## ').blocks), [
        (heading, '', false),
      ]);
    });

    test('a pasted "- hello" keeps the text and puts the cursor after it', () {
      final blocks = [b(text, '')];
      final result = applyTextChange(blocks, blocks[0].id, '- hello');
      expect(shapes(result.blocks), [(bullet, 'hello', false)]);
      expect(result.focus?.offset, 5);
    });

    test('no shortcut inside a to-do', () {
      final blocks = [b(todo, '')];
      final result = applyTextChange(blocks, blocks[0].id, '- ');
      expect(shapes(result.blocks), [(todo, '- ', false)]);
      expect(result.focus, isNull);
    });

    test('editing a line saved as "- text" does not turn it into a bullet', () {
      final blocks = [b(text, '- kept as text')];
      final result = applyTextChange(blocks, blocks[0].id, '- kept as texts');
      expect(shapes(result.blocks), [(text, '- kept as texts', false)]);
    });

    test('plain typing changes the text and leaves the cursor alone', () {
      final blocks = [b(text, 'ab')];
      final result = applyTextChange(blocks, blocks[0].id, 'abc');
      expect(result.blocks.single.text, 'abc');
      expect(result.focus, isNull);
    });

    test('unchanged text returns the same blocks', () {
      final blocks = [b(text, 'ab')];
      final result = applyTextChange(blocks, blocks[0].id, 'ab');
      expect(identical(result.blocks, blocks), isTrue);
    });

    test('an unknown id changes nothing', () {
      final blocks = [b(text, 'ab')];
      expect(applyTextChange(blocks, -5, 'x').blocks, same(blocks));
    });
  });

  group('Enter', () {
    test('at the end of a to-do adds a new unticked to-do', () {
      final blocks = [b(todo, 'graphs', checked: true)];
      final result = applyTextChange(
        blocks,
        blocks[0].id,
        'graphs\n',
        cursor: 7,
      );
      expect(shapes(result.blocks), [
        (todo, 'graphs', true),
        (todo, '', false),
      ]);
      expect(result.focus?.id, result.blocks[1].id);
      expect(result.focus?.offset, 0);
    });

    test('in the middle splits the text', () {
      final blocks = [b(bullet, 'abcd')];
      final result = applyTextChange(blocks, blocks[0].id, 'ab\ncd', cursor: 3);
      expect(shapes(result.blocks), [
        (bullet, 'ab', false),
        (bullet, 'cd', false),
      ]);
      expect(result.focus?.id, result.blocks[1].id);
      expect(result.focus?.offset, 0);
    });

    test('after a heading starts plain text', () {
      final blocks = [b(heading, 'Plan')];
      final result = applyTextChange(blocks, blocks[0].id, 'Plan\n', cursor: 5);
      expect(shapes(result.blocks), [
        (heading, 'Plan', false),
        (text, '', false),
      ]);
    });

    test('on an empty list item leaves the list', () {
      for (final type in [todo, bullet, heading]) {
        final blocks = [b(text, 'x'), b(type, '')];
        final result = applyTextChange(blocks, blocks[1].id, '\n', cursor: 1);
        expect(shapes(result.blocks), [(text, 'x', false), (text, '', false)]);
        expect(result.focus?.id, blocks[1].id);
      }
    });

    test('on an empty plain line adds another plain line', () {
      final blocks = [b(text, '')];
      final result = applyTextChange(blocks, blocks[0].id, '\n', cursor: 1);
      expect(result.blocks, hasLength(2));
      expect(result.focus?.id, result.blocks[1].id);
    });

    test('blocks after the edited one stay in place', () {
      final blocks = [b(todo, 'a'), b(todo, 'c')];
      final result = applyTextChange(blocks, blocks[0].id, 'a\nb', cursor: 3);
      expect(result.blocks.map((x) => x.text), ['a', 'b', 'c']);
    });

    test('pasting several lines makes a block per line, markdown included', () {
      final blocks = [b(text, '')];
      const pasted = '# Plan\n- [ ] graphs\n- [x] trees\nnotes';
      final result = applyTextChange(
        blocks,
        blocks[0].id,
        pasted,
        cursor: pasted.length,
      );
      expect(shapes(result.blocks), [
        (heading, 'Plan', false),
        (todo, 'graphs', false),
        (todo, 'trees', true),
        (text, 'notes', false),
      ]);
      expect(result.focus?.id, result.blocks.last.id);
      expect(result.focus?.offset, 5);
    });

    test('Windows line breaks in a paste are handled', () {
      final blocks = [b(text, '')];
      final result = applyTextChange(blocks, blocks[0].id, 'a\r\nb', cursor: 4);
      expect(result.blocks.map((x) => x.text), ['a', 'b']);
    });
  });

  group('Backspace at the start', () {
    test('a list item becomes plain text first', () {
      final blocks = [b(text, 'x'), b(todo, 'goal', checked: true)];
      final result = backspaceAtStart(blocks, blocks[1].id);
      expect(shapes(result.blocks), [
        (text, 'x', false),
        (text, 'goal', false),
      ]);
      expect(result.focus?.id, blocks[1].id);
      expect(result.focus?.offset, 0);
    });

    test('plain text joins the line above, cursor at the join', () {
      final blocks = [b(todo, 'ab'), b(text, 'cd')];
      final result = backspaceAtStart(blocks, blocks[1].id);
      expect(shapes(result.blocks), [(todo, 'abcd', false)]);
      expect(result.focus?.id, blocks[0].id);
      expect(result.focus?.offset, 2);
    });

    test('an empty plain line just disappears into the one above', () {
      final blocks = [b(text, 'ab'), b(text, '')];
      final result = backspaceAtStart(blocks, blocks[1].id);
      expect(result.blocks.single.text, 'ab');
      expect(result.focus?.offset, 2);
    });

    test('the first plain line has nothing above, so nothing changes', () {
      final blocks = [b(text, 'ab')];
      final result = backspaceAtStart(blocks, blocks[0].id);
      expect(result.blocks, same(blocks));
    });
  });

  group('other edits', () {
    test('toggleTodo ticks and unticks, and ignores other types', () {
      var blocks = [b(todo, 'a'), b(bullet, 'b')];
      blocks = toggleTodo(blocks, blocks[0].id);
      expect(blocks[0].checked, isTrue);
      blocks = toggleTodo(blocks, blocks[0].id);
      expect(blocks[0].checked, isFalse);
      expect(toggleTodo(blocks, blocks[1].id), same(blocks));
    });

    test('toggleType switches, and picking the same type returns to text', () {
      var blocks = [b(text, 'a')];
      blocks = toggleType(blocks, blocks[0].id, todo);
      expect(blocks[0].type, todo);
      blocks = toggleType(blocks, blocks[0].id, todo);
      expect(blocks[0].type, text);
    });

    test('leaving a to-do clears its tick', () {
      var blocks = [b(todo, 'a', checked: true)];
      blocks = toggleType(blocks, blocks[0].id, bullet);
      blocks = toggleType(blocks, blocks[0].id, todo);
      expect(blocks[0].checked, isFalse);
    });

    test('deleteBlock never leaves the notebook empty', () {
      final blocks = [b(todo, 'a')];
      final result = deleteBlock(blocks, blocks[0].id);
      expect(shapes(result.blocks), [(text, '', false)]);
      expect(result.focus?.id, result.blocks[0].id);
    });

    test('deleteBlock moves the cursor to the end of the line above', () {
      final blocks = [b(text, 'abc'), b(text, 'x')];
      final result = deleteBlock(blocks, blocks[1].id);
      expect(result.blocks.single.text, 'abc');
      expect(result.focus?.offset, 3);
    });

    test('appendBlock reuses a trailing empty line, else adds one', () {
      final empty = [b(text, 'a'), b(text, '')];
      expect(appendBlock(empty).blocks, hasLength(2));
      final full = [b(text, 'a')];
      final result = appendBlock(full);
      expect(result.blocks, hasLength(2));
      expect(result.focus?.id, result.blocks.last.id);
    });

    test('addTodo replaces a blank notebook, else appends', () {
      final blank = [b(text, '')];
      expect(shapes(addTodo(blank, 'DSA').blocks), [(todo, 'DSA', false)]);
      final used = [b(text, 'note')];
      expect(addTodo(used, 'DSA').blocks.map((x) => x.text), ['note', 'DSA']);
    });
  });

  group('carry over', () {
    List<FocusBlock> sample() => [
      b(heading, 'Plan'),
      b(todo, 'graphs', checked: true),
      b(todo, 'trees'),
      b(text, ''),
      b(text, 'notes'),
    ];

    test('copy all brings everything over, unticked', () {
      final result = carryOverBlocks(sample(), unfinishedOnly: false);
      expect(shapes(result), [
        (heading, 'Plan', false),
        (todo, 'graphs', false),
        (todo, 'trees', false),
        (text, '', false),
        (text, 'notes', false),
      ]);
    });

    test('unfinished only leaves ticked to-dos behind', () {
      final result = carryOverBlocks(sample(), unfinishedOnly: true);
      expect(result.map((x) => x.text), ['Plan', 'trees', '', 'notes']);
    });

    test('copies get fresh ids', () {
      final source = sample();
      final ids = source.map((x) => x.id).toSet();
      final result = carryOverBlocks(source, unfinishedOnly: false);
      expect(result.every((x) => !ids.contains(x.id)), isTrue);
    });

    test('blank edges and doubled blank lines are tidied', () {
      final result = carryOverBlocks([
        b(text, ''),
        b(todo, 'a', checked: true),
        b(text, ''),
        b(text, ''),
        b(todo, 'b'),
        b(text, ''),
      ], unfinishedOnly: true);
      expect(result.map((x) => x.text), ['b']);
    });

    test('nothing left still gives one empty line', () {
      final result = carryOverBlocks([
        b(todo, 'a', checked: true),
      ], unfinishedOnly: true);
      expect(shapes(result), [(text, '', false)]);
    });
  });

  group('progress', () {
    test('counts to-dos, ignoring blank ones and other types', () {
      final progress = FocusProgress.of([
        b(todo, 'a', checked: true),
        b(todo, 'b'),
        b(todo, '  '),
        b(bullet, 'c'),
      ]);
      expect(progress.done, 1);
      expect(progress.total, 2);
      expect(progress.allDone, isFalse);
      expect(progress.fraction, 0.5);
    });

    test('no goals is not "all done"', () {
      expect(FocusProgress.of([b(text, 'x')]).allDone, isFalse);
    });
  });

  group('random edits keep the notebook valid (fuzz)', () {
    const alphabet = [
      'a',
      'b',
      ' ',
      '-',
      '*',
      '#',
      '[',
      ']',
      'x',
      r'\',
      '\n',
      '\n',
      '\r',
      '\r\n',
      '😀',
      '1',
    ];

    String randomText(Random random) => List.generate(
      random.nextInt(12),
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();

    void checkValid(List<FocusBlock> blocks, FocusTarget? focus, String step) {
      expect(blocks, isNotEmpty, reason: step);
      expect(
        blocks.map((x) => x.id).toSet(),
        hasLength(blocks.length),
        reason: 'ids must stay unique: $step',
      );
      for (final x in blocks) {
        expect(x.text.contains(RegExp(r'[\r\n]')), isFalse, reason: step);
        expect(x.checked && x.type != todo, isFalse, reason: step);
      }
      if (focus != null) {
        final target = blocks.where((x) => x.id == focus.id);
        expect(target, hasLength(1), reason: 'focus target exists: $step');
        expect(focus.offset, inInclusiveRange(0, target.single.text.length));
      }
      final saved = serializeFocusMarkdown(blocks);
      expect(
        shapes(parseFocusMarkdown(saved)),
        shapes(blocks),
        reason: 'must round trip: $step',
      );
    }

    test('thousands of random operations', () {
      final random = Random(2026);
      for (var run = 0; run < 300; run++) {
        var blocks = [FocusBlock.create()];
        for (var step = 0; step < 40; step++) {
          final target = blocks[random.nextInt(blocks.length)];
          late final EditResult result;
          final label = 'run $run step $step';
          switch (random.nextInt(8)) {
            case 0 || 1 || 2:
              final next = randomText(random);
              result = applyTextChange(
                blocks,
                target.id,
                next,
                cursor: random.nextInt(next.length + 2) - 1,
              );
            case 3:
              result = backspaceAtStart(blocks, target.id);
            case 4:
              result = EditResult(toggleTodo(blocks, target.id));
            case 5:
              result = EditResult(
                toggleType(
                  blocks,
                  target.id,
                  FocusBlockType.values[random.nextInt(4)],
                ),
              );
            case 6:
              result = random.nextBool()
                  ? deleteBlock(blocks, target.id)
                  : appendBlock(blocks);
            default:
              result = addTodo(blocks, randomText(random));
          }
          blocks = result.blocks;
          checkValid(blocks, result.focus, label);
        }
      }
    });
  });
}
