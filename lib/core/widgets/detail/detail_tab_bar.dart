import 'package:flutter/material.dart';

TabBar buildDetailTabBar({
  required BuildContext context,
  required TabController controller,
  required List<Widget> tabs,
  EdgeInsetsGeometry labelPadding = const EdgeInsets.symmetric(horizontal: 8),
}) {
  final scheme = Theme.of(context).colorScheme;
  final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 10,
        height: 1.1,
      );

  return TabBar(
    controller: controller,
    tabs: tabs,
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
