import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/focus/data/focus_repository.dart';
import 'package:ticky/features/focus/models/carry_offer.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/models/focus_editing.dart' as edit;
import 'package:ticky/features/focus/models/focus_markdown.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

final focusRepositoryProvider = Provider<FocusRepository>(
  (ref) =>
      FocusRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
);

/// How long typing pauses before the notebook is saved. Tests override this.
final focusSaveDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 500),
);

/// A past (or any) day's notebook as saved markdown, live. Read-only views.
final focusNoteProvider = StreamProvider.autoDispose.family<String, String>(
  (ref, dateKey) => ref.watch(focusRepositoryProvider).watchBody(dateKey),
);

/// Everything the notebook UI needs about one day.
class FocusDocState {
  const FocusDocState({
    required this.blocks,
    this.focus,
    this.focusSerial = 0,
    this.focusedId,
    this.offer,
    this.canUndo = false,
  });

  final List<FocusBlock> blocks;

  /// Where the cursor should go next. A field acts on it once per
  /// [focusSerial].
  final FocusTarget? focus;
  final int focusSerial;

  /// The block that has the cursor, for the toolbar. Not saved.
  final int? focusedId;

  /// "Bring yesterday over?", or null when there is nothing to offer.
  final CarryOffer? offer;

  /// Whether there is an edit to take back.
  final bool canUndo;

  FocusProgress get progress => FocusProgress.of(blocks);
  bool get isBlank => edit.isBlankDocument(blocks);

  FocusBlock? get focusedBlock {
    for (final block in blocks) {
      if (block.id == focusedId) return block;
    }
    return null;
  }

  FocusDocState copyWith({
    List<FocusBlock>? blocks,
    FocusTarget? focus,
    int? focusSerial,
    int? Function()? focusedId,
    CarryOffer? Function()? offer,
    bool? canUndo,
  }) {
    return FocusDocState(
      blocks: blocks ?? this.blocks,
      focus: focus ?? this.focus,
      focusSerial: focusSerial ?? this.focusSerial,
      focusedId: focusedId == null ? this.focusedId : focusedId(),
      offer: offer == null ? this.offer : offer(),
      canUndo: canUndo ?? this.canUndo,
    );
  }
}

/// Holds one day's notebook while it is on screen and saves it as it changes.
///
/// The Home card and the editor sheet watch the same instance, so they can
/// never disagree. Saving is debounced, and the last edit is written when the
/// notebook goes off screen ([flush] and dispose).
class FocusDocController extends AsyncNotifier<FocusDocState> {
  FocusDocController(this.dateKey);

  final String dateKey;

  late FocusRepository _repo;
  late Duration _saveDelay;
  Timer? _debounce;
  String? _pendingBody;
  Future<void> _writes = Future<void>.value();

  // Undo: snapshots of the blocks from before each edit. Typing is grouped, so
  // one undo takes back a burst of typing, not a single letter.
  static const _typingGroup = Duration(seconds: 2);
  static const _undoLimit = 100;
  final _undoStack = <List<FocusBlock>>[];
  late Clock _clock;
  bool _lastWasTyping = false;
  DateTime? _lastTypingAt;

  @override
  Future<FocusDocState> build() async {
    _clock = ref.watch(clockProvider);
    _repo = ref.watch(focusRepositoryProvider);
    _saveDelay = ref.watch(focusSaveDelayProvider);
    final repo = _repo;

    ref.onDispose(() {
      _debounce?.cancel();
      final body = _pendingBody;
      if (body != null) {
        _pendingBody = null;
        unawaited(_enqueue(repo, body).catchError((Object _) {}));
      }
    });

    final blocks = edit.ensureNotEmpty(
      parseFocusMarkdown(await repo.getBody(dateKey)),
    );
    return FocusDocState(
      blocks: blocks,
      offer: edit.isBlankDocument(blocks) ? await _loadOffer() : null,
    );
  }

  /// Yesterday's (or the last written day's) notebook, unless it was already
  /// answered today. The offer is optional, so any failure just means none.
  Future<CarryOffer?> _loadOffer() async {
    try {
      final settings = ref.read(settingsRepositoryProvider);
      if (await settings.getFocusCarryAnsweredDateKey() == dateKey) return null;
      final note = await _repo.latestBefore(dateKey);
      if (note == null) return null;
      return CarryOffer.fromBody(note.dateKey, note.body);
    } on Object {
      return null;
    }
  }

  FocusDocState? get _current => state.value;

  /// Takes a snapshot before a change, unless it continues a burst of typing.
  void _remember(List<FocusBlock> before, {required bool typing}) {
    final now = _clock();
    final lastAt = _lastTypingAt;
    final continuing =
        typing &&
        _lastWasTyping &&
        lastAt != null &&
        now.difference(lastAt) < _typingGroup;
    if (!continuing) {
      _undoStack.add(before);
      if (_undoStack.length > _undoLimit) _undoStack.removeAt(0);
    }
    _lastWasTyping = typing;
    _lastTypingAt = typing ? now : null;
  }

  void _apply(EditResult result, {bool typing = false}) {
    final current = _current;
    if (current == null) return;
    final changed = !identical(result.blocks, current.blocks);
    if (!changed && result.focus == null) return;
    if (changed) _remember(current.blocks, typing: typing);
    state = AsyncData(
      current.copyWith(
        blocks: result.blocks,
        focus: result.focus,
        focusSerial: result.focus == null ? null : current.focusSerial + 1,
        canUndo: _undoStack.isNotEmpty,
      ),
    );
    if (changed) _markChanged(result.blocks);
  }

  /// Takes back the last edit (or burst of typing).
  void undo() {
    final current = _current;
    if (current == null || _undoStack.isEmpty) return;
    final blocks = _undoStack.removeLast();
    _lastWasTyping = false;
    _lastTypingAt = null;
    state = AsyncData(
      current.copyWith(blocks: blocks, canUndo: _undoStack.isNotEmpty),
    );
    _markChanged(blocks);
  }

  // ---- Editing -------------------------------------------------------------

  void onTextChanged(int id, String text, {int? cursor}) {
    final current = _current;
    if (current == null) return;
    final result = edit.applyTextChange(
      current.blocks,
      id,
      text,
      cursor: cursor,
    );
    // Same lines, same cursor: plain typing (not a split or a shortcut).
    final typing =
        result.focus == null && result.blocks.length == current.blocks.length;
    _apply(result, typing: typing);
  }

  void onBackspaceAtStart(int id) {
    final current = _current;
    if (current == null) return;
    _apply(edit.backspaceAtStart(current.blocks, id));
  }

  void toggleTodo(int id) {
    final current = _current;
    if (current == null) return;
    _apply(EditResult(edit.toggleTodo(current.blocks, id)));
  }

  void toggleType(int id, FocusBlockType type) {
    final current = _current;
    if (current == null) return;
    _apply(EditResult(edit.toggleType(current.blocks, id, type)));
  }

  void deleteBlock(int id) {
    final current = _current;
    if (current == null) return;
    _apply(edit.deleteBlock(current.blocks, id));
  }

  void moveBlock(int id, int delta) {
    final current = _current;
    if (current == null) return;
    _apply(EditResult(edit.moveBlock(current.blocks, id, delta)));
  }

  /// Removes every ticked goal.
  void clearDone() {
    final current = _current;
    if (current == null) return;
    _apply(EditResult(edit.removeDoneGoals(current.blocks)));
  }

  /// The page as markdown, for copying out.
  String get markdown {
    final current = _current;
    return current == null ? '' : serializeFocusMarkdown(current.blocks);
  }

  void appendBlock() {
    final current = _current;
    if (current == null) return;
    _apply(edit.appendBlock(current.blocks));
  }

  void addTodo(String text) {
    final current = _current;
    if (current == null) return;
    _apply(edit.addTodo(current.blocks, text));
  }

  // ---- Focus (not saved) ---------------------------------------------------

  void setFocused(int? id) {
    final current = _current;
    if (current == null || current.focusedId == id) return;
    state = AsyncData(current.copyWith(focusedId: () => id));
  }

  /// Puts the cursor at the end of the last line.
  void focusEnd() {
    final current = _current;
    if (current == null || current.blocks.isEmpty) return;
    final last = current.blocks.last;
    state = AsyncData(
      current.copyWith(
        focus: FocusTarget(last.id, last.text.length),
        focusSerial: current.focusSerial + 1,
      ),
    );
  }

  // ---- Carry over ----------------------------------------------------------

  /// Fills today's page from the offered day. With [unfinishedOnly], ticked
  /// to-dos stay behind.
  Future<void> acceptOffer({required bool unfinishedOnly}) async {
    final current = _current;
    final offer = current?.offer;
    if (current == null || offer == null) return;
    final blocks = edit.carryOverBlocks(
      parseFocusMarkdown(offer.body),
      unfinishedOnly: unfinishedOnly,
    );
    _remember(current.blocks, typing: false);
    state = AsyncData(
      current.copyWith(
        blocks: blocks,
        offer: () => null,
        canUndo: _undoStack.isNotEmpty,
      ),
    );
    _markChanged(blocks);
    await _rememberAnswer();
  }

  /// "Start fresh": keeps the page empty and does not ask again today.
  Future<void> declineOffer() async {
    final current = _current;
    if (current == null || current.offer == null) return;
    state = AsyncData(current.copyWith(offer: () => null));
    await _rememberAnswer();
  }

  Future<void> _rememberAnswer() async {
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setFocusCarryAnsweredDateKey(dateKey);
    } on Object {
      // Worst case the question is asked once more.
    }
  }

  // ---- Saving --------------------------------------------------------------

  void _markChanged(List<FocusBlock> blocks) {
    _pendingBody = serializeFocusMarkdown(blocks);
    _debounce?.cancel();
    _debounce = Timer(_saveDelay, () => unawaited(flush()));
  }

  /// Writes any unsaved edit now. Called when the sheet closes and when the
  /// app goes to the background.
  Future<void> flush() async {
    _debounce?.cancel();
    final body = _pendingBody;
    if (body == null) return;
    _pendingBody = null;
    try {
      await _enqueue(_repo, body);
    } on Object {
      // Keep it, so the next change or flush tries again.
      _pendingBody ??= body;
    }
  }

  Future<void> _enqueue(FocusRepository repo, String body) {
    final next = _writes.then((_) => repo.save(dateKey, body));
    _writes = next.catchError((Object _) {});
    return next;
  }
}

/// No automatic retry: a failed read of the notebook should not loop.
final focusDocProvider = AsyncNotifierProvider.autoDispose
    .family<FocusDocController, FocusDocState, String>(
      FocusDocController.new,
      retry: (_, _) => null,
    );
