import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Fades [child] in while sliding it up by [offsetY].
///
/// Uses `FadeTransition` (no `Opacity` widget, so no saveLayer). [delay] is
/// part of the same controller timeline, so no timers are involved. The
/// controller only exists while [play] was true when the widget was created;
/// changing [play] later does not interrupt a running animation. Under
/// reduced motion the child is returned as is.
class AppFadeSlide extends StatefulWidget {
  const AppFadeSlide({
    required this.child,
    super.key,
    this.duration = AppMotion.base,
    this.curve = AppMotion.enter,
    this.delay = Duration.zero,
    this.offsetY = AppMotion.slideOffsetY,
    this.play = true,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;

  /// Vertical travel in logical pixels; 0 gives a pure fade.
  final double offsetY;

  /// Whether to animate when the widget is first built.
  final bool play;

  @override
  State<AppFadeSlide> createState() => _AppFadeSlideState();
}

class _AppFadeSlideState extends State<AppFadeSlide>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (widget.play && !AppMotion.reducedOf(context)) _start();
  }

  void _start() {
    final total = widget.delay + widget.duration;
    final controller = AnimationController(vsync: this, duration: total);
    final delayFraction = total.inMicroseconds == 0
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _controller = controller;
    _animation = CurvedAnimation(
      parent: controller,
      curve: Interval(delayFraction, 1, curve: widget.curve),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null) return widget.child;
    final offsetY = widget.offsetY;
    return FadeTransition(
      opacity: animation,
      child: offsetY == 0
          ? widget.child
          : AnimatedBuilder(
              animation: animation,
              child: widget.child,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, offsetY * (1 - animation.value)),
                child: child,
              ),
            ),
    );
  }
}
