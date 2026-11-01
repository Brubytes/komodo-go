import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/breakpoints.dart';
import 'package:komodo_go/core/widgets/adaptive_bottom_navigation_bar.dart';

/// Left navigation rail used instead of the bottom bar on medium and expanded
/// windows. Takes the same [AdaptiveNavigationItem]s as the bottom bar so both
/// stay in sync.
///
/// Labels are always shown; at [kExtendedRailMinWidth] and wider the rail is
/// extended (icon and label side by side).
class AdaptiveNavigationRail extends StatelessWidget {
  const AdaptiveNavigationRail({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    required this.extended,
    this.stripWidth,
    this.stripTopGap = 0,
    this.stripOnRight = true,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<AdaptiveNavigationItem> items;
  final bool extended;

  /// When set, the rail sits in the system's vertical bar strip of this width
  /// (iOS 27.1+ foldable inner display): icon-only, on a tinted surface, and
  /// [stripTopGap] below the status bar / camera region.
  final double? stripWidth;
  final double stripTopGap;
  final bool stripOnRight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget icon(AdaptiveNavigationItem item, Widget base) {
      final badged = item.badged(base);
      return item.key == null
          ? badged
          : KeyedSubtree(key: item.key, child: badged);
    }

    final strip = stripWidth;
    final destinations = [
      for (final item in items)
        NavigationRailDestination(
          icon: icon(item, item.icon),
          selectedIcon: icon(item, item.activeIcon ?? item.icon),
          label: Text(item.label),
          padding: strip == null
              ? null
              : const EdgeInsets.symmetric(vertical: 2),
        ),
    ];

    if (strip != null) {
      final side = BorderSide(color: scheme.outlineVariant);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: stripOnRight ? Border(left: side) : Border(right: side),
        ),
        child: SizedBox(
          width: strip,
          child: Padding(
            padding: EdgeInsets.only(top: stripTopGap),
            // The strip already is the inset; the rail must not add it again.
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              removeRight: true,
              removeTop: true,
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onTap,
                minWidth: strip,
                // The shortest display (466pt) minus camera and bottom inset
                // may not fit five destinations.
                scrollable: true,
                labelType: NavigationRailLabelType.none,
                backgroundColor: Colors.transparent,
                indicatorColor: scheme.primaryContainer,
                selectedIconTheme: IconThemeData(
                  color: scheme.onPrimaryContainer,
                ),
                unselectedIconTheme: IconThemeData(
                  color: scheme.onSurfaceVariant,
                ),
                leading: const SizedBox(height: 10),
                destinations: destinations,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        extended: extended,
        // Keeps the first destination off the edge when the top inset is 0.
        leading: const SizedBox(height: 10),
        minExtendedWidth: 220,
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        destinations: destinations,
      ),
    );
  }
}
