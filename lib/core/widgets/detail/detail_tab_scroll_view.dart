import 'package:flutter/material.dart';

/// Default readable width for detail tab content; wider panes center it.
const double detailContentMaxWidth = 960;

class DetailTabScrollView extends StatelessWidget {
  const DetailTabScrollView({
    required this.sliver,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.scrollKey,
    this.maxContentWidth = detailContentMaxWidth,
    super.key,
  });

  factory DetailTabScrollView.box({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    double maxContentWidth = detailContentMaxWidth,
    Key? key,
  }) {
    return DetailTabScrollView._(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      maxContentWidth: maxContentWidth,
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  factory DetailTabScrollView.list({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    ScrollPhysics physics = const AlwaysScrollableScrollPhysics(),
    Key? scrollKey,
    double maxContentWidth = detailContentMaxWidth,
    Key? key,
  }) {
    return DetailTabScrollView._(
      key: key,
      scrollKey: scrollKey,
      physics: physics,
      padding: padding,
      maxContentWidth: maxContentWidth,
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }

  const DetailTabScrollView._({
    required this.sliver,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.scrollKey,
    this.maxContentWidth = detailContentMaxWidth,
    super.key,
  });

  final Widget sliver;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final Key? scrollKey;

  /// Content is centered and capped at this width. Pass `double.infinity` to
  /// let it span the whole pane.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    final padding = this.padding;

    return CustomScrollView(
      key: scrollKey,
      physics: physics,
      slivers: [
        SliverOverlapInjector(handle: handle),
        // Local width, so it caps correctly inside a list/detail pane too.
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final resolved = padding.resolve(Directionality.of(context));
            final extra =
                ((constraints.crossAxisExtent -
                            resolved.horizontal -
                            maxContentWidth) /
                        2)
                    .clamp(0.0, double.infinity);
            return SliverPadding(
              padding: resolved.copyWith(
                left: resolved.left + extra,
                right: resolved.right + extra,
              ),
              sliver: sliver,
            );
          },
        ),
      ],
    );
  }
}
