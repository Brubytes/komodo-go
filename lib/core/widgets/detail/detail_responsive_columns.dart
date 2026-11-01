import 'package:flutter/material.dart';

/// Stacks [children] in one column, or flows them into two columns once the
/// available (local) width reaches [twoColumnMinWidth].
///
/// Children are dealt out alternately (left, right, left...) so reading order
/// stays roughly top-to-bottom. Columns size to their content; they are not
/// stretched to equal heights. Decides from its own constraints, never from
/// the window, so it behaves inside a list/detail pane or beside a rail.
class DetailResponsiveColumns extends StatelessWidget {
  const DetailResponsiveColumns({
    required this.children,
    this.spacing = 12,
    this.twoColumnMinWidth = defaultTwoColumnMinWidth,
    super.key,
  });

  /// Local width from which detail content flows into two columns.
  static const double defaultTwoColumnMinWidth = 720;

  final List<Widget> children;

  /// Gap between rows and between the two columns.
  final double spacing;
  final double twoColumnMinWidth;

  /// Number of columns used for a local [width].
  static int columnsFor(double width, {double? twoColumnMinWidth}) =>
      width >= (twoColumnMinWidth ?? defaultTwoColumnMinWidth) ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = children.length < 2
            ? 1
            : columnsFor(
                constraints.maxWidth,
                twoColumnMinWidth: twoColumnMinWidth,
              );

        Widget stack(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              items[i],
            ],
          ],
        );

        if (columns == 1) {
          return Column(
            key: const ValueKey('detail_columns_1'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [stack(children)],
          );
        }

        return Row(
          key: const ValueKey('detail_columns_2'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: stack([
                for (var i = 0; i < children.length; i += 2) children[i],
              ]),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: stack([
                for (var i = 1; i < children.length; i += 2) children[i],
              ]),
            ),
          ],
        );
      },
    );
  }
}
