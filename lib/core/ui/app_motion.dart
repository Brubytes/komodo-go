import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;

  static const double slideOffsetY = 12;

  static Duration stagger(int index, {int stepMs = 20, int maxMs = 160}) {
    final ms = (index * stepMs).clamp(0, maxMs);
    return Duration(milliseconds: ms);
  }
}

class AppFadeSlide extends StatefulWidget {
  const AppFadeSlide({
    required this.child,
    super.key,
    this.duration = AppMotion.base,
    this.curve = AppMotion.enterCurve,
    this.delay = Duration.zero,
    this.offsetY = AppMotion.slideOffsetY,
    this.play = true,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final double offsetY;
  final bool play;

  @override
  State<AppFadeSlide> createState() => _AppFadeSlideState();
}

class _AppFadeSlideState extends State<AppFadeSlide>
    with SingleTickerProviderStateMixin {
  // Only created when the widget actually animates, so non-animating cards
  // (the vast majority in long lists) carry no controller or ticker.
  AnimationController? _controller;
  Animation<double>? _animation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    if (widget.play) _startAnimation();
  }

  @override
  void didUpdateWidget(AppFadeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller != null && !widget.play && controller.value != 1) {
      _delayTimer?.cancel();
      controller.value = 1;
    }
  }

  void _startAnimation() {
    final controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller = controller;
    _animation = CurvedAnimation(parent: controller, curve: widget.curve);
    if (widget.delay == Duration.zero) {
      controller.forward();
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null) return widget.child;

    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final value = animation.value;
        final dy = lerpDouble(widget.offsetY, 0, value) ?? 0;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}
