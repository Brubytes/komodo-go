import 'package:flutter/material.dart';

class AppSecondaryFab extends StatelessWidget {
  const AppSecondaryFab.extended({
    required this.onPressed,
    required this.label,
    this.icon,
    this.tooltip,
    this.heroTag,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget label;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLightMode = theme.brightness == Brightness.light;
    final isDarkMode = theme.brightness == Brightness.dark;

    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: icon,
      label: label,
      tooltip: tooltip,
      heroTag: heroTag,
      backgroundColor: isLightMode
          ? colorScheme.primary
          : (isDarkMode ? colorScheme.secondary : null),
      foregroundColor: isLightMode
          ? colorScheme.onPrimary
          : (isDarkMode ? colorScheme.onSecondary : null),
    );
  }
}
