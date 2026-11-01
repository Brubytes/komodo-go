import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/layout/list_detail_layout.dart';

/// Page for stack routes inside a shell branch.
///
/// On narrow windows it uses the platform page transition (horizontal slide).
/// Where [ListDetailLayout] shows list and detail side by side the page just
/// fades, and the page below does not parallax-shift under it. The decision is
/// made from the branch's current width on every build, so it adapts after a
/// fold/unfold; the page content is reparented between the two transition
/// shapes instead of being rebuilt.
class SplitAwarePage extends Page<void> {
  const SplitAwarePage({
    required this.child,
    this.splitMinWidth = kListDetailSplitMinWidth,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  /// Width from which the page is shown in a side-by-side layout.
  final double splitMinWidth;

  @override
  Route<void> createRoute(BuildContext context) => _SplitAwareRoute(this);
}

class _SplitAwareRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  _SplitAwareRoute(SplitAwarePage page) : super(settings: page);

  final GlobalKey _childKey = GlobalKey(debugLabel: 'splitAwarePageChild');

  SplitAwarePage get _page => settings as SplitAwarePage;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  bool get _isSplit {
    final box = navigator?.context.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        box.size.width >= _page.splitMinWidth;
  }

  @override
  Duration get transitionDuration =>
      _isSplit ? const Duration(milliseconds: 160) : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _isSplit
      ? const Duration(milliseconds: 160)
      : super.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final keyed = KeyedSubtree(key: _childKey, child: child);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _page.splitMinWidth) {
          return FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
            child: keyed,
          );
        }
        return super.buildTransitions(
          context,
          animation,
          secondaryAnimation,
          keyed,
        );
      },
    );
  }
}
