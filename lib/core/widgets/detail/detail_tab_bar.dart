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
        fontSize: 10,
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
        unawaited(
          scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToPinned();
      });
    };
  }

  final tabBar = TabBar(
    controller: controller,
    tabs: tabs,
    onTap: resolvedOnTap,
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
