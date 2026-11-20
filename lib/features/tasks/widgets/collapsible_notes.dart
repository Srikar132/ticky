import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// Shows [child] in full when it fits in [collapsedHeight], otherwise cuts it
/// with a fade and a "See more" button that opens it up.
///
/// [background] is the colour behind the child, used for the fade.
class CollapsibleNotes extends StatefulWidget {
  const CollapsibleNotes({
    super.key,
    required this.child,
    required this.background,
    this.collapsedHeight = 160,
  });

  final Widget child;
  final Color background;
  final double collapsedHeight;

  @override
  State<CollapsibleNotes> createState() => _CollapsibleNotesState();
}

class _CollapsibleNotesState extends State<CollapsibleNotes> {
  final _contentKey = GlobalKey();

  /// Height of the child laid out in full. Null until measured.
  double? _fullHeight;
  bool _expanded = false;

  void _measure() {
    final height = _contentKey.currentContext?.size?.height;
    if (height != null && height != _fullHeight && mounted) {
      setState(() => _fullHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Measure after every layout: the width can change (rotation, text size).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final full = _fullHeight;
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    // Until measured, show the child as it is so there is something to measure.
    if (full == null) return content;

    // A small overshoot is not worth a button.
    final overflows = full > widget.collapsedHeight + 24;
    if (!overflows) return content;

    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final height = _expanded ? full : widget.collapsedHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: reduceMotion ? Duration.zero : AppMotion.medium,
          curve: AppMotion.curve,
          height: height,
          child: Stack(
            children: [
              ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: content,
                ),
              ),
              if (!_expanded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.background.withValues(alpha: 0),
                            widget.background,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            minimumSize: const Size(0, AppSizes.compactControl),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(_expanded ? 'See less' : 'See more'),
        ),
      ],
    );
  }
}
