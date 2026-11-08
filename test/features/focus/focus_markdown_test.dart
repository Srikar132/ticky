import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_markdown.dart';

typedef Shape = (FocusBlockType, String, bool);

List<Shape> shapes(List<FocusBlock> blocks) => [
  for (final b in blocks) (b.type, b.text, b.checked),
];

FocusBlock block(FocusBlockType type, String text, {bool checked = false}) =>
    FocusBlock.create(type: type, text: text, checked: checked);

void main() {
  group('parse', () {
    test('reads every block type', () {
      final blocks = parseFocusMarkdown(
        '# Plan\n- [ ] DSA graphs\n- [x] Trees\n- a note\nplain',
      );
      expect(shapes(blocks), [
        (FocusBlockType.heading, 'Plan', false),
        (FocusBlockType.todo, 'DSA graphs', false),
        (FocusBlockType.todo, 'Trees', true),
        (FocusBlockType.bullet, 'a note', false),
        (FocusBlockType.text, 'plain', false),
      ]);
    });

    test('empty source is one empty text block', () {
      expect(shapes(parseFocusMarkdown('')), [
        (FocusBlockType.text, '', false),
      ]);
    });

    test('accepts other markdown markers and capital X', () {
      expect(shapes(parseFocusMarkdown('* a\n+ b\n* [X] c\n## d')), [
        (FocusBlockType.bullet, 'a', false),
        (FocusBlockType.bullet, 'b', false),
        (FocusBlockType.todo, 'c', true),
        (FocusBlockType.heading, 'd', false),
      ]);
    });

    test('handles Windows and old Mac line breaks', () {
      expect(parseFocusMarkdown('a\r\nb\rc').map((b) => b.text), [
        'a',
        'b',
        'c',
      ]);
    });

    test('markers without a space are plain text', () {
      expect(shapes(parseFocusMarkdown('#hashtag\n-5 degrees\n**bold**')), [
        (FocusBlockType.text, '#hashtag', false),
        (FocusBlockType.text, '-5 degrees', false),
        (FocusBlockType.text, '**bold**', false),
      ]);
    });

    test('a lone marker is an empty block', () {
      expect(shapes(parseFocusMarkdown('-\n#\n- [ ]')), [
        (FocusBlockType.bullet, '', false),
        (FocusBlockType.heading, '', false),
        (FocusBlockType.todo, '', false),
      ]);
    });
  });

  group('serialize', () {
    test('writes the canonical form', () {
      final text = serializeFocusMarkdown([
        block(FocusBlockType.heading, 'Plan'),
        block(FocusBlockType.todo, 'Graphs'),
        block(FocusBlockType.todo, 'Trees', checked: true),
        block(FocusBlockType.bullet, 'note'),
        block(FocusBlockType.text, 'plain'),
      ]);
      expect(text, '# Plan\n- [ ] Graphs\n- [x] Trees\n- note\nplain');
    });

    test('text that looks like markup is escaped and survives', () {
      final original = [
        block(FocusBlockType.text, '- not a bullet'),
        block(FocusBlockType.text, '# not a heading'),
        block(FocusBlockType.text, '- [ ] not a todo'),
        block(FocusBlockType.text, r'\leading backslash'),
        block(FocusBlockType.bullet, '[ ] not a todo either'),
        block(FocusBlockType.todo, r'\x'),
      ];
      final text = serializeFocusMarkdown(original);
      expect(shapes(parseFocusMarkdown(text)), shapes(original));
    });

    test('a stray line break cannot split a line', () {
      final text = serializeFocusMarkdown([block(FocusBlockType.text, 'a\nb')]);
      expect(parseFocusMarkdown(text), hasLength(1));
    });
  });

  group('round trip (fuzz)', () {
    const alphabet = [
      'a',
      'b',
      'Z',
      ' ',
      ' ',
      '-',
      '*',
      '+',
      '#',
      '[',
      ']',
      'x',
      'X',
      r'\',
      '1',
      'é',
      '😀',
      '\t',
      '>',
      '.',
      '_',
      '`',
      '‍',
    ];

    String randomText(Random random, {bool lineBreaks = false}) {
      final length = random.nextInt(14);
      final chars = [
        ...alphabet,
        if (lineBreaks) ...['\n', '\r', '\r\n'],
      ];
      return List.generate(
        length,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
    }

    test('blocks survive serialize then parse', () {
      final random = Random(7);
      for (var round = 0; round < 4000; round++) {
        final blocks = List.generate(1 + random.nextInt(6), (_) {
          final type = FocusBlockType.values[random.nextInt(4)];
          return block(type, randomText(random), checked: random.nextBool());
        });
        final text = serializeFocusMarkdown(blocks);
        expect(
          shapes(parseFocusMarkdown(text)),
          shapes(blocks),
          reason: 'blocks: $blocks\nmarkdown: ${text.replaceAll('\n', '⏎')}',
        );
      }
    });

    test('any string parses, and parsing is stable', () {
      final random = Random(11);
      for (var round = 0; round < 4000; round++) {
        final source = List.generate(
          random.nextInt(5),
          (_) => randomText(random, lineBreaks: true),
        ).join('\n');
        final blocks = parseFocusMarkdown(source);
        expect(blocks, isNotEmpty);
        expect(blocks.any((b) => b.text.contains(RegExp(r'[\r\n]'))), isFalse);

        final once = serializeFocusMarkdown(blocks);
        final twice = serializeFocusMarkdown(parseFocusMarkdown(once));
        expect(twice, once, reason: 'source: ${source.replaceAll('\n', '⏎')}');
      }
    });
  });
}
