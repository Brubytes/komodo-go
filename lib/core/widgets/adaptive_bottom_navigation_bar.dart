import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdaptiveBottomNavigationBar extends StatelessWidget {
  const AdaptiveBottomNavigationBar({
    required this.selectedIndex,
    required this.onTap,
    required this.items,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<AdaptiveNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isCupertino =
        !kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 360;

    if (isCupertino) {
      final colorScheme = Theme.of(context).colorScheme;
      final baseTextStyle = CupertinoTheme.of(
        context,
      ).textTheme.tabLabelTextStyle;
      final tabLabelTextStyle = baseTextStyle.copyWith(
        fontSize: isCompact ? 10 : baseTextStyle.fontSize,
        overflow: TextOverflow.ellipsis,
      );

      return CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          textTheme: CupertinoTheme.of(
            context,
          ).textTheme.copyWith(tabLabelTextStyle: tabLabelTextStyle),
        ),
        child: CupertinoTabBar(
          currentIndex: selectedIndex,
          onTap: onTap,
          activeColor: colorScheme.primary,
          inactiveColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          items: [
            for (final item in items)
              BottomNavigationBarItem(
                icon: item.icon,
                activeIcon: item.activeIcon ?? item.icon,
                label: item.label,
              ),
          ],
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelTextStyle = WidgetStateProperty.resolveWith((states) {
      final color = states.contains(WidgetState.selected)
          ? colorScheme.onSurface
          : colorScheme.onSurfaceVariant;
      return TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: isCompact ? 11 : 12,
        overflow: TextOverflow.ellipsis,
      );
    });

    return NavigationBarTheme(
      data: NavigationBarTheme.of(
        context,
      ).copyWith(labelTextStyle: labelTextStyle),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onTap,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: item.icon,
              selectedIcon: item.activeIcon,
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class AdaptiveNavigationItem {
  const AdaptiveNavigationItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final Widget icon;
  final String label;
  final Widget? activeIcon;
}
