import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

PreferredSizeWidget buildDetailTabBar({
  required BuildContext context,
  required TabController controller,
  required List<Widget> tabs,
  EdgeInsetsGeometry labelPadding = const EdgeInsets.symmetric(horizontal: 8),
  ScrollController? outerScrollController,
  GlobalKey<NestedScrollViewState>? nestedScrollKey,
  double outerScrollTopInset = 12,
  ValueChanged<int>? onTap,
  bool debugScrollLogging = false,
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

      void log(String message) {
        if (!debugScrollLogging || !kDebugMode) return;
        debugPrint('[DetailTabBar] $message');
      }

      void scrollToPinned() {
        final nestedState = nestedScrollKey?.currentState;
        if (nestedState != null) {
          final inner = nestedState.innerController;
          if (inner.hasClients) {
            final positions = inner.positions;
            if (positions.isNotEmpty) {
              final innerMin = positions.first.minScrollExtent;
              log(
                'tap=$index innerPixels=${positions.first.pixels.toStringAsFixed(1)} '
                'innerMin=${positions.first.minScrollExtent.toStringAsFixed(1)} '
                'innerMax=${positions.first.maxScrollExtent.toStringAsFixed(1)}',
              );
              if (nestedState.outerController.hasClients) {
                final outerPos = nestedState.outerController.position;
                log(
                  'outerPixels=${outerPos.pixels.toStringAsFixed(1)} '
                  'outerMin=${outerPos.minScrollExtent.toStringAsFixed(1)} '
                  'outerMax=${outerPos.maxScrollExtent.toStringAsFixed(1)}',
                );
              }
              log('animate inner to $innerMin');
              unawaited(
                inner
                    .animateTo(
                      innerMin,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    )
                    .then((_) {
                      if (!debugScrollLogging || !kDebugMode) return;
                      if (nestedState.outerController.hasClients) {
                        final outerPos = nestedState.outerController.position;
                        log(
                          'after outerPixels=${outerPos.pixels.toStringAsFixed(1)} '
                          'outerMax=${outerPos.maxScrollExtent.toStringAsFixed(1)}',
                        );
                      }
                      if (inner.hasClients) {
                        final innerPos = inner.position;
                        log(
                          'after innerPixels=${innerPos.pixels.toStringAsFixed(1)} '
                          'innerMax=${innerPos.maxScrollExtent.toStringAsFixed(1)}',
                        );
                      }
                    }),
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

        log(
          'fallback animate outer to $target '
          '(pixels=${position.pixels.toStringAsFixed(1)} '
          'min=${position.minScrollExtent.toStringAsFixed(1)} '
          'max=${position.maxScrollExtent.toStringAsFixed(1)})',
        );
        scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToPinned();
      });
    };
  }

  const tabHeight = 44.0;
  const iconSize = 18.0;
  const iconGap = 6.0;
  final horizontalLabelPadding = labelPadding.resolve(
    Directionality.of(context),
  );
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);

  double labelWidth(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget buildTabBar({
    required bool showIcons,
    required bool scrollable,
  }) {
    final compactTabs = [
      for (final tab in tabs)
        if (tab is Tab &&
            tab.child == null &&
            (tab.icon != null || tab.text != null))
          Tab(
            key: tab.key,
            height: tabHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIcons && tab.icon != null)
                  IconTheme.merge(
                    data: const IconThemeData(size: iconSize),
                    child: tab.icon!,
                  ),
                if (showIcons && tab.icon != null && tab.text != null)
                  const SizedBox(width: iconGap),
                if (tab.text != null)
                  Flexible(
                    child: Text(
                      tab.text!,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
              ],
            ),
          )
        else
          tab,
    ];

    return TabBar(
      controller: controller,
      tabs: compactTabs,
      onTap: resolvedOnTap,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : null,
      labelStyle: labelStyle,
      unselectedLabelStyle: labelStyle,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          width: 3,
          color: scheme.primary,
        ),
        insets: const EdgeInsets.symmetric(horizontal: 14),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: scheme.outlineVariant,
      labelPadding: labelPadding,
    );
  }

  final adaptive = _AdaptiveDetailTabBar(
    tabs: tabs,
    height: tabHeight,
    labelWidth: labelWidth,
    horizontalPadding: horizontalLabelPadding.horizontal,
    iconWidth: iconSize + iconGap,
    builder: buildTabBar,
  );
  final tabBar = PreferredSize(
    preferredSize: const Size.fromHeight(tabHeight + 2),
    child: adaptive,
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

/// Chooses between inline icon+label, label-only and scrollable layouts based
/// on the width actually available, so tabs never overflow.
class _AdaptiveDetailTabBar extends StatelessWidget {
  const _AdaptiveDetailTabBar({
    required this.tabs,
    required this.height,
    required this.labelWidth,
    required this.horizontalPadding,
    required this.iconWidth,
    required this.builder,
  });

  final List<Widget> tabs;
  final double height;
  final double Function(String) labelWidth;
  final double horizontalPadding;
  final double iconWidth;
  final Widget Function({required bool showIcons, required bool scrollable})
  builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final count = tabs.isEmpty ? 1 : tabs.length;
        final perTab = available / count;

        var maxLabel = 0.0;
        var maxInline = 0.0;
        for (final tab in tabs) {
          if (tab is! Tab) continue;
          final text = tab.text;
          final label = text == null ? 0.0 : labelWidth(text);
          final hasIcon = tab.icon != null;
          if (label > maxLabel) maxLabel = label;
          final inline = label + (hasIcon && text != null ? iconWidth : 0);
          if (inline > maxInline) maxInline = inline;
        }
        // Small safety margin for rounding / glyph hinting differences.
        const safety = 4.0;
        final inlineFits = maxInline + horizontalPadding + safety <= perTab;
        final labelsFit = maxLabel + horizontalPadding + safety <= perTab;

        final Widget bar;
        if (inlineFits) {
          bar = builder(showIcons: true, scrollable: false);
        } else if (labelsFit) {
          bar = builder(showIcons: false, scrollable: false);
        } else {
          bar = builder(showIcons: false, scrollable: true);
        }
        return bar;
      },
    );
  }
}
