import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Local width from which the dashboard splits into two columns.
const double homeDashboardTwoColumnMinWidth = 720;

/// Widest the dashboard grows; wider panes center it.
const double homeDashboardMaxWidth = 1200;

/// Arranges the dashboard sections as a scrolling page.
///
/// Compact widths keep the single column: attention, server overview,
/// alerts, ops pulse. From [homeDashboardTwoColumnMinWidth] the server
/// overview spans the top and the rest sits in two columns (attention and
/// alerts beside the ops pulse). The decision uses the local width, so it
/// follows window resizes and works beside a navigation rail or list pane.
class HomeDashboardLayout extends StatelessWidget {
  const HomeDashboardLayout({
    required this.attention,
    required this.serverOverview,
    required this.alerts,
    required this.opsPulse,
    super.key,
  });

  final Widget attention;
  final Widget serverOverview;
  final Widget alerts;
  final Widget opsPulse;

  static const double _columnGap = 16;

  /// Whether a local [width] gets the two-column arrangement.
  static bool isTwoColumn(double width) =>
      width >= homeDashboardTwoColumnMinWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final twoColumn = isTwoColumn(width);
        final side = twoColumn ? 16.0 : 12.0;
        // Centers the capped content without a nested Center/ConstrainedBox.
        final extra = math.max(
          0,
          (width - side * 2 - homeDashboardMaxWidth) / 2,
        );
        final padding = EdgeInsets.fromLTRB(
          side + extra,
          twoColumn ? 16 : 12,
          side + extra,
          20,
        );

        if (!twoColumn) {
          return ListView(
            padding: padding,
            children: [attention, serverOverview, alerts, opsPulse],
          );
        }

        return ListView(
          padding: padding,
          children: [
            serverOverview,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    key: const ValueKey('home_column_primary'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [attention, alerts],
                  ),
                ),
                const SizedBox(width: _columnGap),
                Expanded(
                  child: Column(
                    key: const ValueKey('home_column_secondary'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [opsPulse],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
