import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

PreferredSizeWidget buildDetailTabBar({
  required BuildContext context,
  required TabController controller,
  required List<Widget> tabs,
  EdgeInsetsGeometry labelPadding = const EdgeInsets.symmetric(horizontal: 8),
  ScrollController? outerScrollController,
  GlobalKey<NestedScrollViewState>? nestedScrollKey,
  double outerScrollTopInset = 12,
  ValueChanged<int>? onTap,
  double bottomGap = 0,
}) {
  final scheme = Theme.of(context).colorScheme;
  final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  ValueChanged<int>? resolvedOnTap;
  if (onTap != null ||
      outerScrollController != null ||
      nestedScrollKey != null) {
    resolvedOnTap = (index) {
      onTap?.call(index);

      void scrollToPinned() {
        if (!context.mounted) return;
        final nestedState = nestedScrollKey?.currentState;
        if (nestedState != null) {
          final inner = nestedState.innerController;
          if (inner.hasClients) {
            final positions = inner.positions;
            if (positions.isNotEmpty) {
              unawaited(
                AppMotion.animateOrJump(
                  inner,
                  positions.first.minScrollExtent,
                  context,
                ),
              );
              return;
            }
          }
        }

        final scrollController = outerScrollController;
        if (scrollController == null || !scrollController.hasClients) return;

        final position = scrollController.position;
        final rawTarget = position.maxScrollExtent - outerScrollTopInset;
        final target = rawTarget.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - target).abs() < 0.5) return;

        unawaited(AppMotion.animateOrJump(scrollController, target, context));
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToPinned();
      });
    };
  }

  const iconSize = 20.0;
  const tabHeight = 56.0;

  // Icon stacked above the label; labels scale down instead of clipping so
  // every tab keeps an equal-width slot.
  final compactTabs = [
    for (final tab in tabs)
      if (tab is Tab &&
          tab.child == null &&
          (tab.icon != null || tab.text != null))
        Tab(
          key: tab.key,
          height: tabHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (tab.icon != null)
                IconTheme.merge(
                  data: const IconThemeData(size: iconSize),
                  child: tab.icon!,
                ),
              if (tab.icon != null && tab.text != null)
                const SizedBox(height: 4),
              if (tab.text != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tab.text!, maxLines: 1, softWrap: false),
                ),
            ],
          ),
        )
      else
        tab,
  ];

  final tabBar = PreferredSize(
    preferredSize: const Size.fromHeight(tabHeight + 2),
    child: TabBar(
      controller: controller,
      tabs: compactTabs,
      onTap: resolvedOnTap,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: scheme.primary),
        insets: const EdgeInsets.symmetric(horizontal: 14),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant,
      labelPadding: labelPadding,
    ),
  );

  if (bottomGap <= 0) return tabBar;

  return PreferredSize(
    preferredSize: Size.fromHeight(tabBar.preferredSize.height + bottomGap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tabBar,
        SizedBox(height: bottomGap),
      ],
    ),
  );
}
