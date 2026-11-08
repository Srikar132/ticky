import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/focus/models/focus_block.dart';

/// An invisible character kept at the start of every field's text.
///
/// Phone keyboards send no key event when Backspace is pressed in an empty
/// field, so "Backspace on an empty line" cannot be detected directly. With
/// this marker in front, Backspace at the start of a line deletes the marker,
/// which does produce a text change we can recognise. The marker never leaves
/// this file: the notebook's blocks and the saved markdown never contain it.
const focusMarker = '​';

/// One editable line of the notebook.
///
/// It owns its text controller and focus node and speaks in plain callbacks.
/// What an edit means (split, join, convert) is decided by `focus_editing.dart`,
/// not here.
class FocusBlockField extends StatefulWidget {
  const FocusBlockField({
    super.key,
    required this.block,
    required this.hint,
    required this.style,
    this.verticalPadding = 8,
    required this.focusTarget,
    required this.focusSerial,
    required this.onChanged,
    required this.onBackspaceAtStart,
    required this.onFocused,
  });

  final FocusBlock block;
  final String hint;
  final TextStyle style;

  /// Space above and below the text. The sheet sets it so a single line is as
  /// tall as the row's tick, which centres the two on each other.
  final double verticalPadding;

  /// A cursor move requested by an edit. A field acts on it once per
  /// [focusSerial], and only if it is addressed to this block.
  final FocusTarget? focusTarget;
  final int focusSerial;

  /// The text (without the marker) and cursor offset after a change.
  final void Function(String text, int cursor) onChanged;
  final VoidCallback onBackspaceAtStart;
  final VoidCallback onFocused;

  @override
  State<FocusBlockField> createState() => _FocusBlockFieldState();
}

class _FocusBlockFieldState extends State<FocusBlockField> {
  late final TextEditingController _controller;
  late final FocusNode _node;
  int _handledSerial = -1;
  bool _settingValue = false;

  String get _body => _controller.text.replaceAll(focusMarker, '');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _writeValue(widget.block.text, cursor: widget.block.text.length);
    _controller.addListener(_keepCursorAfterMarker);
    _node = FocusNode()..addListener(_onFocusChange);
    _applyFocusRequest();
  }

  @override
  void didUpdateWidget(FocusBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The block changed under us (a split, a join, a shortcut): show it.
    if (_body != widget.block.text) {
      final cursor = _controller.selection.isValid
          ? _controller.selection.extentOffset - 1
          : widget.block.text.length;
      _writeValue(widget.block.text, cursor: cursor);
    }
    _applyFocusRequest();
  }

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_node.hasFocus) widget.onFocused();
  }

  /// Sets the text with the marker in front and the cursor at [cursor], an
  /// offset into the text without the marker.
  void _writeValue(String body, {required int cursor}) {
    _settingValue = true;
    _controller.value = TextEditingValue(
      text: '$focusMarker$body',
      selection: TextSelection.collapsed(
        offset: 1 + math.max(0, math.min(cursor, body.length)),
      ),
    );
    _settingValue = false;
  }

  /// The cursor may not sit in front of the marker, or a tap at the very start
  /// would let Backspace delete it by accident.
  void _keepCursorAfterMarker() {
    if (_settingValue) return;
    final selection = _controller.selection;
    if (!selection.isValid || !_controller.text.startsWith(focusMarker)) return;
    if (selection.start >= 1 && selection.end >= 1) return;
    _settingValue = true;
    _controller.selection = TextSelection(
      baseOffset: math.max(1, selection.baseOffset),
      extentOffset: math.max(1, selection.extentOffset),
    );
    _settingValue = false;
  }

  void _applyFocusRequest() {
    final target = widget.focusTarget;
    if (target == null ||
        target.id != widget.block.id ||
        widget.focusSerial == _handledSerial) {
      return;
    }
    _handledSerial = widget.focusSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _node.requestFocus();
      final body = _body;
      _controller.selection = TextSelection.collapsed(
        offset: 1 + math.max(0, math.min(target.offset, body.length)),
      );
    });
  }

  void _onChanged(String raw) {
    final markerKept = raw.startsWith(focusMarker);
    final body = raw.replaceAll(focusMarker, '');
    final extent = _controller.selection.extentOffset;
    final cursor = math.max(
      0,
      math.min(
        body.length,
        extent < 0 ? body.length : extent - (markerKept ? 1 : 0),
      ),
    );

    // Backspace at the start removed only the marker.
    if (!markerKept && body == widget.block.text) {
      _writeValue(body, cursor: 0);
      widget.onBackspaceAtStart();
      return;
    }

    widget.onChanged(body, cursor);

    // Keep exactly one marker in front, whatever the user did to the text.
    final expected = '$focusMarker$body';
    if (_controller.text != expected && _body == body) {
      _writeValue(body, cursor: cursor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // The marker makes the field's text never empty, so the usual hint
        // would never show. Draw it ourselves.
        if (widget.hint.isNotEmpty)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _body.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.verticalPadding,
                    ),
                    child: IgnorePointer(
                      child: Text(
                        widget.hint,
                        style: widget.style.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        TextField(
          controller: _controller,
          focusNode: _node,
          style: widget.style,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          maxLines: null,
          cursorColor: scheme.onSurface,
          decoration: bareInputDecoration(context, hint: '').copyWith(
            contentPadding: EdgeInsets.symmetric(
              vertical: widget.verticalPadding,
            ),
          ),
          onChanged: _onChanged,
        ),
      ],
    );
  }
}
