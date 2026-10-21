import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Drop-in replacement for `AnimatedSwitcher` with the app's motion language.
///
/// The outgoing child fades out quickly, the incoming child fades in with a
/// subtle 0.98 to 1 scale, and the whole thing is wrapped in an `AnimatedSize`
/// (unless [animateSize] is false) so height changes do not jump. Children
/// are top-center aligned. Give each logical state a stable `key` (state
/// kind, not data instance) so polling never triggers a switch.
///
/// Reduced motion: opacity cross-fade at `fast`, no scale, no size animation.
class AppSwitcher extends StatelessWidget {
  const AppSwitcher({
    required this.child,
    super.key,
    this.duration,
    this.alignment = Alignment.topCenter,
    this.animateSize = true,
  });

  final Widget child;

  /// Defaults to `AppMotion.base`.
  final Duration? duration;
  final AlignmentGeometry alignment;
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reducedOf(context);
    final inDuration = reduced ? AppMotion.fast : duration ?? AppMotion.base;

    Widget switcher = AnimatedSwitcher(
      duration: inDuration,
      reverseDuration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduced) return fade;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: fade,
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      child: child,
    );

    if (animateSize && !reduced) {
      switcher = AnimatedSize(
        duration: AppMotion.base,
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: switcher,
      );
    }
    return switcher;
  }
}
