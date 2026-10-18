import 'package:flutter/cupertino.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

/// Page transition used on every platform.
///
/// Delegates to the Cupertino transition (horizontal slide with edge
/// swipe-back) so iOS and Android behave identically. Under reduced motion it
/// is a plain, short fade instead.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const CupertinoPageTransitionsBuilder _cupertino =
      CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _cupertino.transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _cupertino.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reducedOf(context)) {
      // The route duration cannot depend on the context, so compress the fade
      // into the first part of the timeline to keep it short.
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.4),
          reverseCurve: const Interval(0.6, 1),
        ),
        child: child,
      );
    }
    return _cupertino.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
