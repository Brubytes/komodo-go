import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Subtle press feedback: scales [child] to `AppMotion.pressScale` while a
/// pointer is down.
///
/// Uses a raw `Listener`, so it never competes in the gesture arena and does
/// not steal taps from `InkWell` children. Moving the pointer past touch slop
/// (i.e. the user starts scrolling) releases the press. Disabled under reduced
/// motion or when [enabled] is false.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    super.key,
    this.enabled = true,
    this.scale = AppMotion.pressScale,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;
  Offset? _origin;

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || AppMotion.reducedOf(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _origin = event.position;
        _set(true);
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (origin != null && (event.position - origin).distance > kTouchSlop) {
          _origin = null;
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.micro,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
