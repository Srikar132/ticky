/// What a line of the focus notebook is.
enum FocusBlockType { text, heading, bullet, todo }

int _nextBlockId = 1;

/// A process-unique id. Ids only identify a block on screen (widget keys,
/// focus). They are never saved: the saved form is plain markdown.
int newFocusBlockId() => _nextBlockId++;

/// One line of the notebook. A block never contains a line break.
class FocusBlock {
  const FocusBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.checked = false,
  });

  /// A fresh block with a new id.
  factory FocusBlock.create({
    FocusBlockType type = FocusBlockType.text,
    String text = '',
    bool checked = false,
  }) => FocusBlock(
    id: newFocusBlockId(),
    type: type,
    text: text,
    checked: type == FocusBlockType.todo && checked,
  );

  final int id;
  final FocusBlockType type;
  final String text;

  /// Only meaningful for [FocusBlockType.todo]. Always false for other types.
  final bool checked;

  bool get isTodo => type == FocusBlockType.todo;

  /// Whether the block shows nothing at all.
  bool get isBlank => text.trim().isEmpty;

  /// Changing [type] away from a to-do clears [checked].
  FocusBlock copyWith({FocusBlockType? type, String? text, bool? checked}) {
    final nextType = type ?? this.type;
    return FocusBlock(
      id: id,
      type: nextType,
      text: text ?? this.text,
      checked: nextType == FocusBlockType.todo && (checked ?? this.checked),
    );
  }

  /// Same content, ignoring [id]. For tests and change detection.
  bool sameContent(FocusBlock other) =>
      type == other.type && text == other.text && checked == other.checked;

  @override
  String toString() => 'FocusBlock#$id(${type.name}, "$text", $checked)';
}

/// Where the cursor should go after an edit.
class FocusTarget {
  const FocusTarget(this.id, this.offset);

  final int id;

  /// Character offset inside the block's text.
  final int offset;
}

/// The result of an edit: the new blocks and, when the cursor has to move, where.
class EditResult {
  const EditResult(this.blocks, [this.focus]);

  final List<FocusBlock> blocks;
  final FocusTarget? focus;
}

/// How many to-dos are done. Blank to-dos are ignored.
class FocusProgress {
  const FocusProgress({required this.done, required this.total});

  factory FocusProgress.of(Iterable<FocusBlock> blocks) {
    var done = 0;
    var total = 0;
    for (final block in blocks) {
      if (!block.isTodo || block.isBlank) continue;
      total++;
      if (block.checked) done++;
    }
    return FocusProgress(done: done, total: total);
  }

  static const none = FocusProgress(done: 0, total: 0);

  final int done;
  final int total;

  bool get hasGoals => total > 0;
  bool get allDone => total > 0 && done == total;
  double get fraction => total == 0 ? 0 : done / total;
}
