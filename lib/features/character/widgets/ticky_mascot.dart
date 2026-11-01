import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/character/models/mascot_assets.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';

/// Ticky.
///
/// Motion is event-driven, never ambient: at rest he is perfectly still.
///  - Appears with one short fade-and-settle.
///  - A tap, or a change of mood, plays a brief spring squash-and-stretch with
///    his feet planted.
///  - Nothing animates when the system asks to reduce motion.
///
/// Presentation only: the mood is decided elsewhere.
class TickyMascot extends StatefulWidget {
  const TickyMascot({
    super.key,
    required this.mood,
    this.height = 120,
    this.onTap,
    this.idlePose,
  });

  final MascotMood mood;
  final double height;
  final VoidCallback? onTap;

  /// A pose id from [MascotAssets.poses] shown instead of the plain idle
  /// picture. Only used while [mood] is idle; every other mood keeps its own
  /// picture so Ticky's reactions stay readable.
  final String? idlePose;

  @override
  State<TickyMascot> createState() => _TickyMascotState();
}

class _TickyMascotState extends State<TickyMascot>
    with SingleTickerProviderStateMixin {
  /// How far the squash-and-stretch goes: 0.07 = 7% in height.
  static const _squash = 0.07;

  /// Underdamped, so the settle overshoots once or twice and calms down.
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 17,
  );

  /// Spring displacement. 0 is rest, -1 is fully squashed.
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// [impact] 1 is a full squash; smaller values are gentler.
  void _kick(double impact) {
    if (_reduceMotion) return;
    _motion.animateWith(SpringSimulation(_spring, -impact, 0, 0));
  }

  @override
  void didUpdateWidget(TickyMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _kick(0.6);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _handleTap() {
    _kick(1);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.height;
    final image = SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: AppMotion.medium,
        switchInCurve: AppMotion.curve,
        child: _MascotImage(
          key: ValueKey((widget.mood, widget.idlePose)),
          mood: widget.mood,
          idlePose: widget.idlePose,
        ),
      ),
    );

    Widget mascot = AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final d = _motion.value;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(
            1 - _squash * 0.5 * d,
            1 + _squash * d,
            1,
          ),
          child: child,
        );
      },
      child: image,
    );

    if (!_reduceMotion) {
      // One-time entrance. It only plays when Ticky first appears.
      mascot = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * size * 0.08),
            child: child,
          ),
        ),
        child: mascot,
      );
    }

    return Semantics(
      button: widget.onTap != null,
      label: 'Ticky',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _handleTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _ContactShadow(width: size * 0.5),
              mascot,
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft, static ellipse under Ticky's feet. The cut-out art has no shadow of
/// its own, so this keeps him from looking pasted on.
class _ContactShadow extends StatelessWidget {
  const _ContactShadow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: SizedBox(
          width: width,
          height: width * 0.16,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x47000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MascotImage extends StatelessWidget {
  const _MascotImage({super.key, required this.mood, this.idlePose});

  final MascotMood mood;
  final String? idlePose;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      MascotAssets.pathFor(mood, idlePose: idlePose),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => const Icon(
        Icons.access_time_filled_rounded,
        size: 56,
        color: Colors.white54,
      ),
    );
  }
}
