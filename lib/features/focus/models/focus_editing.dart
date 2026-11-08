import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_markdown.dart';

// Every edit to the notebook is a pure function from blocks to blocks. The
// editor widget only forwards what the user did; all the rules live here so
// they can be tested without a screen.

class _Shortcut {
  const _Shortcut(this.type, this.consumed, {this.checked = false});

  final FocusBlockType type;

  /// How many characters of the typed prefix to remove.
  final int consumed;
  final bool checked;
}

final _doneShortcut = RegExp(r'^(?:[-*+] )?\[[xX]\] ');
final _todoShortcut = RegExp(r'^(?:[-*+] )?\[ ?\] ');
final _bulletShortcut = RegExp(r'^[-*+] ');
final _headingShortcut = RegExp(r'^#{1,6} ');

/// The block type a line turns into when it starts with `[] `, `- `, `# `...
_Shortcut? _shortcutFor(String line) {
  final done = _doneShortcut.firstMatch(line);
  if (done != null) {
    return _Shortcut(FocusBlockType.todo, done.end, checked: true);
  }
  final todo = _todoShortcut.firstMatch(line);
  if (todo != null) return _Shortcut(FocusBlockType.todo, todo.end);
  final bullet = _bulletShortcut.firstMatch(line);
  if (bullet != null) return _Shortcut(FocusBlockType.bullet, bullet.end);
  final heading = _headingShortcut.firstMatch(line);
  if (heading != null) return _Shortcut(FocusBlockType.heading, heading.end);
  return null;
}

int _indexOf(List<FocusBlock> blocks, int id) =>
    blocks.indexWhere((b) => b.id == id);

List<FocusBlock> _replaceAt(
  List<FocusBlock> blocks,
  int index,
  FocusBlock block,
) => [...blocks.sublist(0, index), block, ...blocks.sublist(index + 1)];

/// A notebook always has at least one block to type in.
List<FocusBlock> ensureNotEmpty(List<FocusBlock> blocks) =>
    blocks.isEmpty ? [FocusBlock.create()] : blocks;

/// Whether the notebook shows nothing.
bool isBlankDocument(List<FocusBlock> blocks) => blocks.every((b) => b.isBlank);

/// The user changed the text of block [id] to [newText], with the cursor at
/// [cursor] (an offset into [newText]; the end when unknown).
///
/// - A line break (Enter, or a paste) splits the block. A to-do or bullet
///   continues the list; a heading or text starts plain text. Enter on an
///   empty list item leaves the list instead.
/// - Typing `[] `, `- ` or `# ` at the start of a plain line turns it into a
///   to-do, bullet or heading.
/// - Anything else is just new text, and [EditResult.focus] stays null so the
///   field keeps its own cursor.
EditResult applyTextChange(
  List<FocusBlock> blocks,
  int id,
  String newText, {
  int? cursor,
}) {
  final index = _indexOf(blocks, id);
  if (index < 0) return EditResult(blocks);
  final source = blocks[index];
  final text = normalizeNewlines(newText);
  final position = (cursor ?? text.length).clamp(0, text.length);

  // A shortcut only fires when the text *becomes* one, so editing a line that
  // was deliberately saved as "- text" does not suddenly turn into a bullet.
  final canConvert =
      source.type == FocusBlockType.text && _shortcutFor(source.text) == null;

  if (!text.contains('\n')) {
    if (text == source.text) return EditResult(blocks);
    final shortcut = canConvert ? _shortcutFor(text) : null;
    if (shortcut != null) {
      final rest = text.substring(shortcut.consumed);
      return EditResult(
        _replaceAt(
          blocks,
          index,
          source.copyWith(
            type: shortcut.type,
            text: rest,
            checked: shortcut.checked,
          ),
        ),
        FocusTarget(id, (position - shortcut.consumed).clamp(0, rest.length)),
      );
    }
    return EditResult(_replaceAt(blocks, index, source.copyWith(text: text)));
  }

  final lines = text.split('\n');

  // Enter on an empty list item or heading leaves it.
  if (lines.length == 2 &&
      lines[0].isEmpty &&
      lines[1].isEmpty &&
      source.type != FocusBlockType.text) {
    return EditResult(
      _replaceAt(
        blocks,
        index,
        source.copyWith(type: FocusBlockType.text, text: ''),
      ),
      FocusTarget(id, 0),
    );
  }

  final continuation = switch (source.type) {
    FocusBlockType.todo => FocusBlockType.todo,
    FocusBlockType.bullet => FocusBlockType.bullet,
    _ => FocusBlockType.text,
  };

  final created = <FocusBlock>[];
  final consumed = <int>[];

  final firstShortcut = canConvert ? _shortcutFor(lines.first) : null;
  if (firstShortcut != null) {
    final rest = lines.first.substring(firstShortcut.consumed);
    created.add(
      source.copyWith(
        type: firstShortcut.type,
        text: rest,
        checked: firstShortcut.checked,
      ),
    );
    consumed.add(firstShortcut.consumed);
  } else {
    created.add(source.copyWith(text: lines.first));
    consumed.add(0);
  }

  for (final line in lines.skip(1)) {
    final shortcut = _shortcutFor(line);
    if (shortcut != null) {
      created.add(
        FocusBlock.create(
          type: shortcut.type,
          text: line.substring(shortcut.consumed),
          checked: shortcut.checked,
        ),
      );
      consumed.add(shortcut.consumed);
    } else {
      created.add(FocusBlock.create(type: continuation, text: line));
      consumed.add(0);
    }
  }

  // Which of the new lines holds the cursor, and where in it.
  var remaining = position;
  var lineIndex = 0;
  while (lineIndex < lines.length - 1 && remaining > lines[lineIndex].length) {
    remaining -= lines[lineIndex].length + 1;
    lineIndex++;
  }
  final target = created[lineIndex];
  final offset = (remaining - consumed[lineIndex]).clamp(0, target.text.length);

  return EditResult([
    ...blocks.sublist(0, index),
    ...created,
    ...blocks.sublist(index + 1),
  ], FocusTarget(target.id, offset));
}

/// Backspace pressed with the cursor at the very start of block [id].
///
/// A list item or heading becomes plain text first. Plain text joins the end
/// of the block above. The first block has nothing above, so nothing happens.
EditResult backspaceAtStart(List<FocusBlock> blocks, int id) {
  final index = _indexOf(blocks, id);
  if (index < 0) return EditResult(blocks);
  final block = blocks[index];

  if (block.type != FocusBlockType.text) {
    return EditResult(
      _replaceAt(blocks, index, block.copyWith(type: FocusBlockType.text)),
      FocusTarget(id, 0),
    );
  }
  if (index == 0) return EditResult(blocks, FocusTarget(id, 0));

  final previous = blocks[index - 1];
  final merged = previous.copyWith(text: previous.text + block.text);
  return EditResult([
    ...blocks.sublist(0, index - 1),
    merged,
    ...blocks.sublist(index + 1),
  ], FocusTarget(previous.id, previous.text.length));
}

/// Ticks or unticks a to-do.
List<FocusBlock> toggleTodo(List<FocusBlock> blocks, int id) {
  final index = _indexOf(blocks, id);
  if (index < 0 || !blocks[index].isTodo) return blocks;
  return _replaceAt(
    blocks,
    index,
    blocks[index].copyWith(checked: !blocks[index].checked),
  );
}

/// Sets the block's type from the toolbar. Choosing the type the block
/// already has turns it back into plain text.
List<FocusBlock> toggleType(
  List<FocusBlock> blocks,
  int id,
  FocusBlockType type,
) {
  final index = _indexOf(blocks, id);
  if (index < 0) return blocks;
  final current = blocks[index].type;
  return _replaceAt(
    blocks,
    index,
    blocks[index].copyWith(type: current == type ? FocusBlockType.text : type),
  );
}

/// Removes a block. Never leaves the notebook empty.
EditResult deleteBlock(List<FocusBlock> blocks, int id) {
  final index = _indexOf(blocks, id);
  if (index < 0) return EditResult(blocks);
  final rest = [...blocks.sublist(0, index), ...blocks.sublist(index + 1)];
  if (rest.isEmpty) {
    final fresh = FocusBlock.create();
    return EditResult([fresh], FocusTarget(fresh.id, 0));
  }
  if (index > 0) {
    final above = rest[index - 1];
    return EditResult(rest, FocusTarget(above.id, above.text.length));
  }
  return EditResult(rest, FocusTarget(rest.first.id, 0));
}

/// Tapping below the last line: focus it if it is empty, else add a new line.
EditResult appendBlock(List<FocusBlock> blocks) {
  final list = ensureNotEmpty(blocks);
  if (list.last.isBlank) return EditResult(list, FocusTarget(list.last.id, 0));
  final fresh = FocusBlock.create();
  return EditResult([...list, fresh], FocusTarget(fresh.id, 0));
}

/// Adds a to-do with [text], reusing a lone empty line instead of leaving a
/// gap above it.
EditResult addTodo(List<FocusBlock> blocks, String text) {
  final clean = normalizeNewlines(text).replaceAll('\n', ' ');
  final todo = FocusBlock.create(type: FocusBlockType.todo, text: clean);
  final target = FocusTarget(todo.id, clean.length);
  if (isBlankDocument(blocks)) return EditResult([todo], target);
  return EditResult([...blocks, todo], target);
}

/// What to bring over from an earlier day: its blocks as fresh, unticked copies.
///
/// With [unfinishedOnly], ticked to-dos are left behind. Blank lines at the
/// edges and doubled blank lines are tidied away.
List<FocusBlock> carryOverBlocks(
  List<FocusBlock> source, {
  required bool unfinishedOnly,
}) {
  final copies = <FocusBlock>[];
  for (final block in source) {
    if (unfinishedOnly && block.isTodo && block.checked) continue;
    final copy = FocusBlock.create(type: block.type, text: block.text);
    final previousBlank = copies.isNotEmpty && copies.last.isBlank;
    if (copy.isBlank && (copies.isEmpty || previousBlank)) continue;
    copies.add(copy);
  }
  while (copies.isNotEmpty && copies.last.isBlank) {
    copies.removeLast();
  }
  return ensureNotEmpty(copies);
}

/// Moves a block one step up ([delta] -1) or down (+1). At the edge nothing
/// changes. The cursor stays where it is, because the block keeps its id.
List<FocusBlock> moveBlock(List<FocusBlock> blocks, int id, int delta) {
  final index = _indexOf(blocks, id);
  final target = index + delta;
  if (index < 0 || target < 0 || target >= blocks.length) return blocks;
  final moved = [...blocks];
  final block = moved.removeAt(index);
  moved.insert(target, block);
  return moved;
}

/// The notebook without its ticked goals. Never leaves it empty, and returns
/// the same list when there is nothing to remove.
List<FocusBlock> removeDoneGoals(List<FocusBlock> blocks) {
  if (!blocks.any((b) => b.isTodo && b.checked)) return blocks;
  return ensureNotEmpty([
    for (final block in blocks)
      if (!(block.isTodo && block.checked)) block,
  ]);
}
