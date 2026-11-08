import 'package:ticky/features/focus/models/focus_block.dart';

// The saved form of a day's focus is plain markdown, one block per line:
//
//   # Heading            heading
//   - item               bullet     (also `* ` and `+ `)
//   - [ ] goal           to-do      (`- [x] goal` when done)
//   anything else        text
//
// A line that would be read as markup but is meant as text gets a leading
// backslash (`\- not a bullet`). Parsing never throws: every string is valid.

final _todo = RegExp(r'^[-*+] \[([ xX])\](?: (.*))?$', dotAll: true);
final _bullet = RegExp(r'^[-*+](?: (.*))?$', dotAll: true);
final _heading = RegExp(r'^#{1,6}(?: (.*))?$', dotAll: true);

String _unescape(String body) =>
    body.startsWith(r'\') ? body.substring(1) : body;

FocusBlock _parseLine(String line) {
  final todo = _todo.firstMatch(line);
  if (todo != null) {
    return FocusBlock.create(
      type: FocusBlockType.todo,
      text: _unescape(todo.group(2) ?? ''),
      checked: todo.group(1) != ' ',
    );
  }
  final bullet = _bullet.firstMatch(line);
  if (bullet != null) {
    return FocusBlock.create(
      type: FocusBlockType.bullet,
      text: _unescape(bullet.group(1) ?? ''),
    );
  }
  final heading = _heading.firstMatch(line);
  if (heading != null) {
    return FocusBlock.create(
      type: FocusBlockType.heading,
      text: _unescape(heading.group(1) ?? ''),
    );
  }
  return FocusBlock.create(text: _unescape(line));
}

/// Line breaks normalised to `\n`.
String normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Reads saved markdown into blocks. Always returns at least one block.
List<FocusBlock> parseFocusMarkdown(String source) {
  return [
    for (final line in normalizeNewlines(source).split('\n')) _parseLine(line),
  ];
}

String _prefixOf(FocusBlock block) => switch (block.type) {
  FocusBlockType.text => '',
  FocusBlockType.heading => '# ',
  FocusBlockType.bullet => '- ',
  FocusBlockType.todo => block.checked ? '- [x] ' : '- [ ] ',
};

/// Writes blocks as markdown. The inverse of [parseFocusMarkdown].
String serializeFocusMarkdown(List<FocusBlock> blocks) {
  final lines = <String>[];
  for (final block in blocks) {
    // A block never holds a line break; if one slipped in it must not split
    // the line and change the structure.
    final text = block.text.replaceAll(RegExp(r'[\r\n]'), ' ');
    final prefix = _prefixOf(block);
    final plain = FocusBlock(
      id: block.id,
      type: block.type,
      text: text,
      checked: block.isTodo && block.checked,
    );
    final line = '$prefix$text';
    // If the plain line would be read back as something else, escape the body.
    lines.add(_parseLine(line).sameContent(plain) ? line : '$prefix\\$text');
  }
  return lines.join('\n');
}
