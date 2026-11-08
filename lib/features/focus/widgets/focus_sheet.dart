import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/providers/focus_providers.dart';
import 'package:ticky/features/focus/widgets/focus_block_field.dart';
import 'package:ticky/features/focus/widgets/focus_block_views.dart';
import 'package:ticky/features/focus/widgets/focus_marks.dart';
import 'package:ticky/features/focus/widgets/focus_offer_panel.dart';
import 'package:ticky/features/focus/widgets/focus_starters.dart';
import 'package:ticky/features/focus/widgets/focus_toolbar.dart';

/// Opens today's notebook for writing. [focusEnd] puts the cursor in the last
/// line straight away, which also brings up the keyboard.
Future<void> showFocusSheet(
  BuildContext context,
  String dateKey, {
  bool focusEnd = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.tickyColors.tileButter,
    builder: (_) => FocusSheet(dateKey: dateKey, focusEnd: focusEnd),
  );
}

/// The notebook editor: goals you tick, bullets, headings and plain notes, all
/// written in place. A toolbar sets the type of the current line for anyone who
/// does not know the typing shortcuts (`[] `, `- `, `# `).
class FocusSheet extends ConsumerStatefulWidget {
  const FocusSheet({super.key, required this.dateKey, this.focusEnd = false});

  final String dateKey;
  final bool focusEnd;

  @override
  ConsumerState<FocusSheet> createState() => _FocusSheetState();
}

class _FocusSheetState extends ConsumerState<FocusSheet> {
  bool _started = false;
  bool _copied = false;
  Timer? _copiedTimer;

  /// Cursor requests made before the sheet opened belong to the card, not here.
  int _baselineSerial = 0;

  FocusDocController get _controller =>
      ref.read(focusDocProvider(widget.dateKey).notifier);

  void _start(FocusDocState doc) {
    _started = true;
    _baselineSerial = doc.focusSerial;
    final wantsKeyboard = widget.focusEnd || (doc.isBlank && doc.offer == null);
    if (wantsKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.focusEnd();
      });
    }
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  /// Puts the page on the clipboard as markdown, which pastes back into the
  /// editor (or into any notes app) as goals and headings.
  Future<void> _copyPage() async {
    await Clipboard.setData(ClipboardData(text: _controller.markdown));
    if (!mounted) return;
    AppFeedback.success();
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _hintFor(FocusBlock block, int count) => switch (block.type) {
    FocusBlockType.todo => 'Goal',
    FocusBlockType.bullet => 'List item',
    FocusBlockType.heading => 'Heading',
    FocusBlockType.text => count == 1 ? 'Write your goals or notes…' : '',
  };

  void _toggleGoal(FocusBlock block) {
    if (block.checked) {
      AppFeedback.tap();
    } else {
      AppFeedback.success();
    }
    _controller.toggleTodo(block.id);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(focusDocProvider(widget.dateKey));
    final doc = async.value;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final insets = media.viewInsets.bottom;

    if (doc != null && !_started) _start(doc);

    final height = math.max(
      320.0,
      math.min(
        media.size.height * 0.94,
        media.size.height - media.padding.top - insets,
      ),
    );

    final Widget content;
    if (doc == null) {
      content = Center(
        child: async.hasError
            ? const Text('Could not open your notebook.')
            : const CircularProgressIndicator(),
      );
    } else {
      final target = doc.focusSerial > _baselineSerial ? doc.focus : null;
      content = SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (doc.offer != null && doc.isBlank)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.75),
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: FocusOfferPanel(
                      offer: doc.offer!,
                      todayKey: widget.dateKey,
                      onAccept: ({required bool unfinishedOnly}) => _controller
                          .acceptOffer(unfinishedOnly: unfinishedOnly),
                      onDecline: _controller.declineOffer,
                    ),
                  ),
                ),
              ),
            for (final block in doc.blocks)
              _BlockRow(
                key: ValueKey('block-${block.id}'),
                block: block,
                hint: _hintFor(block, doc.blocks.length),
                focusTarget: target,
                focusSerial: doc.focusSerial,
                onToggle: () => _toggleGoal(block),
                onChanged: (value, cursor) =>
                    _controller.onTextChanged(block.id, value, cursor: cursor),
                onBackspaceAtStart: () =>
                    _controller.onBackspaceAtStart(block.id),
                onFocused: () => _controller.setFocused(block.id),
              ),
            if (doc.isBlank && doc.offer == null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  top: AppSpacing.xl,
                ),
                child: FocusStarters(onPick: _controller.addTodo),
              ),
            // Tapping the empty page below the last line continues writing.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controller.appendBlock,
              child: const SizedBox(height: 180),
            ),
          ],
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _controller.flush();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              "Today's focus",
                              style: text.titleLarge,
                            ),
                          ),
                          Text(
                            _copied
                                ? 'Copied to clipboard'
                                : DateFormat(
                                    'EEEE, d MMMM',
                                  ).format(parseDateKey(widget.dateKey)),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (doc != null && doc.progress.hasGoals) ...[
                      FocusRing(progress: doc.progress, size: 44),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    if (doc != null)
                      FocusMoreMenu(
                        canClearDone: doc.progress.done > 0,
                        canCopy: !doc.isBlank,
                        onClearDone: _controller.clearDone,
                        onCopy: _copyPage,
                      ),
                    InkPill(
                      label: 'Done',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
              if (doc != null)
                FocusToolbar(
                  focused: doc.focusedBlock,
                  canUndo: doc.canUndo,
                  canMoveUp:
                      doc.focusedBlock != null &&
                      doc.blocks.first.id != doc.focusedId,
                  canMoveDown:
                      doc.focusedBlock != null &&
                      doc.blocks.last.id != doc.focusedId,
                  onUndo: _controller.undo,
                  onType: (type) {
                    final id = doc.focusedId;
                    if (id != null) _controller.toggleType(id, type);
                  },
                  onMove: (delta) {
                    final id = doc.focusedId;
                    if (id != null) _controller.moveBlock(id, delta);
                  },
                  onDelete: () {
                    final id = doc.focusedId;
                    if (id != null) _controller.deleteBlock(id);
                  },
                  keyboardOpen: insets > 0,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    super.key,
    required this.block,
    required this.hint,
    required this.focusTarget,
    required this.focusSerial,
    required this.onToggle,
    required this.onChanged,
    required this.onBackspaceAtStart,
    required this.onFocused,
  });

  final FocusBlock block;
  final String hint;
  final FocusTarget? focusTarget;
  final int focusSerial;
  final VoidCallback onToggle;
  final void Function(String text, int cursor) onChanged;
  final VoidCallback onBackspaceAtStart;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) {
    final style = focusTextStyle(context, block);

    // One line of this text, at the user's text size. The row is at least as
    // tall as the tick, and the text gets equal space above and below, so the
    // tick and the first line share the same centre line.
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = painter.height;
    painter.dispose();
    final rowHeight = math.max(44.0, lineHeight + 8);
    final padding = (rowHeight - lineHeight) / 2;

    final Widget leading = switch (block.type) {
      FocusBlockType.todo => FocusCheck(
        checked: block.checked,
        onTap: onToggle,
      ),
      FocusBlockType.bullet => const FocusBullet(),
      _ => const SizedBox(width: AppSpacing.sm),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: rowHeight,
          child: Center(child: leading),
        ),
        Expanded(
          child: FocusBlockField(
            block: block,
            hint: hint,
            style: style,
            verticalPadding: padding,
            focusTarget: focusTarget,
            focusSerial: focusSerial,
            onChanged: onChanged,
            onBackspaceAtStart: onBackspaceAtStart,
            onFocused: onFocused,
          ),
        ),
      ],
    );
  }
}
