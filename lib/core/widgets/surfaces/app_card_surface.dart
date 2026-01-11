import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';

/// Shared surface styling for list/detail cards.
///
/// Uses the app's CardTheme color so all cards stay consistent across views.
class AppCardSurface extends StatelessWidget {
  const AppCardSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTokens.radiusLg,
    this.showBorder = false,
    this.enableShadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool showBorder;
  final bool enableShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final color =
        theme.cardTheme.color ??
        (isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow);

    final borderColor = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.35 : 0.55,
    );

    final shadows = enableShadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
              blurRadius: isDark ? 24 : 18,
              offset: const Offset(0, 10),
              spreadRadius: isDark ? -6 : -8,
            ),
          ]
        : const <BoxShadow>[];

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
