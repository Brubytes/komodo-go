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
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _startAnimation();
  }

  @override
  void didUpdateWidget(AppFadeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.play && _controller.value != 1) {
      _controller.value = 1;
    }
  }

  void _startAnimation() {
    if (!widget.play) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      unawaited(_controller.forward());
      return;
    }
    _delayTimer = Timer(widget.delay, () {
      if (mounted) unawaited(_controller.forward());
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final value = _animation.value;
        final dy = lerpDouble(widget.offsetY, 0, value) ?? 0;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}
