import 'package:flutter/material.dart';

/// Tab body that fills the available height (e.g. a log viewer) inside a
/// `DetailTabScaffold`, leaving room for the pinned tab bar.
///
/// Unlike `DetailTabScrollView` the child is not scrollable by the outer
/// `NestedScrollView`; it must manage its own scrolling.
class DetailTabFillBody extends StatelessWidget {
  const DetailTabFillBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverOverlapInjector(handle: handle),
        SliverFillRemaining(child: child),
      ],
    );
  }
}
