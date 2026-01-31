import 'package:flutter/material.dart';

class DetailTabScrollView extends StatelessWidget {
  const DetailTabScrollView({
    required this.sliver,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.scrollKey,
    super.key,
  });

  factory DetailTabScrollView.box({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    Key? key,
  }) {
    return DetailTabScrollView(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  factory DetailTabScrollView.list({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    Key? key,
  }) {
    return DetailTabScrollView(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }

  final Widget sliver;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    return CustomScrollView(
      key: scrollKey,
      physics: physics,
      slivers: [
        SliverOverlapInjector(handle: handle),
        SliverPadding(
          padding: padding,
          sliver: sliver,
        ),
      ],
    );
  }
}
