import 'dart:math';

import 'package:flutter/material.dart';

/// How a confetti show looks.
enum ConfettiStyle {
  /// A small pop from one point, for a single completed task.
  pop,

  /// Cannons from both bottom corners plus a light rain from the top, for a
  /// finished day.
  party,
}

/// Plays confetti on top of everything, then removes itself. Does nothing when
/// the system asks to reduce motion.
///
/// [origin] is a point in global (screen) coordinates, used by
/// [ConfettiStyle.pop].
void playConfetti(
  BuildContext context, {
  ConfettiStyle style = ConfettiStyle.pop,
  Offset? origin,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: ExcludeSemantics(
        child: ConfettiBurst(
          style: style,
          origin: origin,
          onDone: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

const _palette = [
  Color(0xFF8B5CF6),
  Color(0xFFF472B6),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFF60A5FA),
  Color(0xFFFB923C),
];

class _Particle {
  const _Particle({
    required this.originFraction,
    required this.originOffset,
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.size,
    required this.spin,
    required this.color,
    required this.shape,
    this.delay = 0,
    this.sway = 0,
  });

  /// Start point as a fraction of the screen, plus a pixel offset.
  final Offset originFraction;
  final Offset originOffset;

  /// Launch direction in radians. -pi/2 is straight up.
  final double angle;

  /// Launch speed in logical pixels per second.
  final double speed;
  final double gravity;
  final double size;

  /// Rotations per second.
  final double spin;
  final Color color;

  /// 0 rectangle, 1 circle, 2 strip.
  final int shape;

  /// Fraction of the show to wait before this piece appears.
  final double delay;

  /// Sideways wobble in pixels, for falling pieces.
  final double sway;
}

List<_Particle> _build(ConfettiStyle style, Offset? origin, Random rng) {
  Color color() => _palette[rng.nextInt(_palette.length)];
  double between(double a, double b) => a + rng.nextDouble() * (b - a);

  switch (style) {
    case ConfettiStyle.pop:
      return [
        for (var i = 0; i < 18; i++)
          _Particle(
            originFraction: Offset.zero,
            originOffset: origin ?? Offset.zero,
            angle: -pi / 2 + between(-1.1, 1.1),
            speed: between(150, 340),
            gravity: 650,
            size: between(5, 9),
            spin: between(-2, 2),
            color: color(),
            shape: rng.nextInt(3),
          ),
      ];
    case ConfettiStyle.party:
      return [
        for (var i = 0; i < 60; i++)
          _Particle(
            originFraction: const Offset(0, 1),
            originOffset: const Offset(-6, 6),
            angle: -pi / 2 + between(0.1, 0.75),
            speed: between(700, 1250),
            gravity: 1100,
            size: between(6, 11),
            spin: between(-3, 3),
            color: color(),
            shape: rng.nextInt(3),
          ),
        for (var i = 0; i < 60; i++)
          _Particle(
            originFraction: const Offset(1, 1),
            originOffset: const Offset(6, 6),
            angle: -pi / 2 - between(0.1, 0.75),
            speed: between(700, 1250),
            gravity: 1100,
            size: between(6, 11),
            spin: between(-3, 3),
            color: color(),
            shape: rng.nextInt(3),
          ),
        for (var i = 0; i < 50; i++)
          _Particle(
            originFraction: Offset(rng.nextDouble(), 0),
            originOffset: const Offset(0, -16),
            angle: pi / 2 + between(-0.25, 0.25),
            speed: between(80, 180),
            gravity: 160,
            size: between(6, 10),
            spin: between(-2, 2),
            color: color(),
            shape: rng.nextInt(3),
            delay: between(0, 0.4),
            sway: between(10, 30),
          ),
      ];
  }
}

/// The confetti itself. Use [playConfetti] to show it over the whole app.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.style,
    this.origin,
    this.onDone,
    this.seed,
  });

  final ConfettiStyle style;
  final Offset? origin;
  final VoidCallback? onDone;

  /// Fixes the random pieces, for tests.
  final int? seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  Duration get _duration => widget.style == ConfettiStyle.pop
      ? const Duration(milliseconds: 1000)
      : const Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _particles = _build(widget.style, widget.origin, Random(widget.seed));
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ConfettiPainter(
          particles: _particles,
          progress: _controller,
          seconds: _duration.inMilliseconds / 1000,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.seconds,
  }) : super(repaint: progress);

  final List<_Particle> particles;
  final Animation<double> progress;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final life = (progress.value - p.delay) / (1 - p.delay);
      if (life <= 0) continue;
      final t = life * seconds * (1 - p.delay);
      final start =
          Offset(
            p.originFraction.dx * size.width,
            p.originFraction.dy * size.height,
          ) +
          p.originOffset;
      final dx = cos(p.angle) * p.speed * t + sin(t * 4) * p.sway;
      final dy = sin(p.angle) * p.speed * t + 0.5 * p.gravity * t * t;
      final position = start + Offset(dx, dy);
      if (position.dy > size.height + 40) continue;

      final fade = life < 0.7 ? 1.0 : ((1 - life) / 0.3).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * t * 2 * pi);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 1.6,
                height: p.size * 0.4,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
