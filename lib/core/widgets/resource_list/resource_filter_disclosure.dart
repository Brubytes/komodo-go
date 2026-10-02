import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

/// Compact filter summary that expands to reveal the full resource filters.
class ResourceFilterDisclosure extends StatelessWidget {
  const ResourceFilterDisclosure({
    required this.expanded,
    required this.activeFilterCount,
    required this.onExpansionChanged,
    required this.child,
    super.key,
  });

  final bool expanded;
  final int activeFilterCount;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final summary = activeFilterCount == 0
        ? 'Template and tag options'
        : '$activeFilterCount active';
    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('resource_filter_disclosure'),
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          leading: const Icon(Icons.tune_outlined),
          title: const Text('Filters'),
          subtitle: Text(summary),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [child],
        ),
      ),
    );
  }
}
