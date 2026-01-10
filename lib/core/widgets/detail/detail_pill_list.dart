import 'package:flutter/material.dart';

import 'detail_pills.dart';

class DetailPillList extends StatelessWidget {
  const DetailPillList({
    required this.items,
    this.emptyLabel = 'None',
    this.tone = PillTone.neutral,
    this.maxItems,
    this.moreLabel = 'More',
    this.spacing = 8,
    this.runSpacing = 8,
    this.leading = const <Widget>[],
    this.showEmptyLabel = true,
    super.key,
  });

  final List<String> items;
  final String emptyLabel;
  final PillTone tone;
  final int? maxItems;
  final String moreLabel;
  final double spacing;
  final double runSpacing;
  final List<Widget> leading;
  final bool showEmptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (!showEmptyLabel) {
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: leading,
        );
      }
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [...leading, TextPill(label: emptyLabel, tone: tone)],
      );
    }

    final capped = maxItems == null ? items : items.take(maxItems!).toList();
    final remaining = items.length - capped.length;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        ...leading,
        for (final item in capped) TextPill(label: item, tone: tone),
        if (remaining > 0)
          ValuePill(label: moreLabel, value: '+$remaining'),
      ],
    );
  }
}
