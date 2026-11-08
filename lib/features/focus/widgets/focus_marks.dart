import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/celebration/widgets/confetti.dart';
import 'package:ticky/features/focus/models/focus_block.dart';

/// The round tick of a goal. Pops a little confetti when it becomes ticked,
/// like the checklist's own check.
class FocusCheck extends StatefulWidget {
  const FocusCheck({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 26,
    this.extent = 44,
  });

  final bool checked;
  final VoidCallback onTap;

  /// Diameter of the circle.
  final double size;

  /// Side of the tappable square around it.
  final double extent;

  @override
  State<FocusCheck> createState() => _FocusCheckState();
}

class _FocusCheckState extends State<FocusCheck> {
  @override
  void didUpdateWidget(FocusCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.checked && widget.checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pop());
    }
  }

  void _pop() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    playConfetti(
      context,
      origin: box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checked = widget.checked;
    return Semantics(
      button: true,
      checked: checked,
      label: checked ? 'Done, tap to undo' : 'Mark as done',
      excludeSemantics: true,
      child: InkResponse(
        enableFeedback: false,
        onTap: widget.onTap,
        radius: 26,
        child: SizedBox(
          width: widget.extent,
          height: widget.extent,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? scheme.inverseSurface : Colors.transparent,
                border: Border.all(
                  color: checked
                      ? scheme.inverseSurface
                      : scheme.onSurface.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                duration: AppMotion.medium,
                curve: Curves.easeOutBack,
                scale: checked ? 1 : 0,
                child: Icon(
                  Icons.check_rounded,
                  size: widget.size - 8,
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small dot in front of a bullet.
class FocusBullet extends StatelessWidget {
  const FocusBullet({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A round progress ring with the count in the middle. Fills with a sweep and
/// turns into a tick once every goal is done.
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.progress, this.size = 56});

  final FocusProgress progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: progress.hasGoals
          ? '${progress.done} of ${progress.total} goals done'
          : 'No goals yet',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.fraction),
          duration: reduce ? Duration.zero : AppMotion.slow,
          curve: AppMotion.curve,
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(
              fraction: value,
              track: scheme.onSurface.withValues(alpha: 0.10),
              arc: scheme.inverseSurface,
              width: size * 0.1,
            ),
            child: child,
          ),
          child: Center(
            child: progress.allDone
                ? Icon(
                    Icons.check_rounded,
                    size: size * 0.46,
                    color: scheme.onSurface,
                  )
                : Text(
                    progress.hasGoals
                        ? '${progress.done}/${progress.total}'
                        : '–',
                    style: text.labelLarge?.copyWith(
                      fontSize: size * 0.27,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.track,
    required this.arc,
    required this.width,
  });

  final double fraction;
  final Color track;
  final Color arc;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (fraction <= 0) return;
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = arc;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      sweep,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.arc != arc ||
      old.width != width;
}

/// A bullet-journal dot grid, drawn faintly behind a page so the card reads as
/// paper rather than as another white box.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({required this.color, this.gap = 18});

  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = gap; y < size.height; y += gap) {
      for (var x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) =>
      old.color != color || old.gap != gap;
}
