import 'package:flutter/widgets.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Cross-fades (with a tiny 4px vertical slide) when [value] changes, e.g.
/// for stat numbers. The first build never animates.
///
/// [child] is the widget showing [value]; it is keyed by [value], so it is
/// only swapped when the value really changes. Under reduced motion it is a
/// plain fade at `fast`.
class AppAnimatedValue extends StatelessWidget {
  const AppAnimatedValue({
    required this.value,
    required this.child,
    super.key,
  });

  /// Convenience for a [Text] value.
  AppAnimatedValue.text(
    String this.value, {
    super.key,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) : child = Text(
         value,
         style: style,
         textAlign: textAlign,
         maxLines: maxLines,
         overflow: overflow,
       );

  /// Identity of the displayed value; a change triggers the transition.
  final Object? value;
  final Widget child;

  static const double _slideY = 4;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reducedOf(context);
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduced) return fade;
        return AnimatedBuilder(
          animation: animation,
          child: fade,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _slideY * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<Object?>(value), child: child),
    );
  }
}
