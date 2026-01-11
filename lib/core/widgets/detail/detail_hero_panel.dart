import 'package:flutter/material.dart';

import 'package:komodo_go/core/widgets/detail/detail_metric_grid.dart';
import 'package:komodo_go/core/widgets/detail/detail_surface.dart';

/// Generic hero panel for detail pages: optional header/footer + metric grid.
class DetailHeroPanel extends StatelessWidget {
  const DetailHeroPanel({
    required this.metrics,
    super.key,
    this.header,
    this.footer,
    this.tintColor,
  });

  final Widget? header;
  final List<DetailMetricTileData> metrics;
  final Widget? footer;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(
      tintColor: tintColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 12)],
          DetailMetricGrid(items: metrics),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}
