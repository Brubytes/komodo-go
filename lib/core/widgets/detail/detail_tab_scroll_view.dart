import 'package:flutter/material.dart';

class DetailTabScrollView extends StatelessWidget {
  const DetailTabScrollView({
    required this.sliver,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.scrollKey,
    this.maxContentWidth,
    super.key,
  }) : child = null;

  factory DetailTabScrollView.box({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    double? maxContentWidth,
    Key? key,
  }) {
    return DetailTabScrollView._(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      maxContentWidth: maxContentWidth,
      sliver: SliverToBoxAdapter(child: child),
      child: child,
    );
  }

  factory DetailTabScrollView.list({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    double? maxContentWidth,
    Key? key,
  }) {
    return DetailTabScrollView._(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      maxContentWidth: maxContentWidth,
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  const DetailTabScrollView._({
    required this.sliver,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.scrollKey,
    this.maxContentWidth,
    super.key,
  });

  final Widget sliver;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final Key? scrollKey;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    final child = this.child;
    final maxContentWidth = this.maxContentWidth;

    return CustomScrollView(
      key: scrollKey,
      physics: physics,
      slivers: [
        SliverOverlapInjector(handle: handle),
        if (child != null && maxContentWidth != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: padding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: child,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: padding,
            sliver: sliver,
          ),
      ],
    );
  }
}
