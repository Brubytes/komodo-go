import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

/// Shared surface styling for detail pages.
///
/// Uses the app's `CardTheme.color` by default so detail surfaces match
/// dashboard/list cards.
class DetailSurface extends StatelessWidget {
  const DetailSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTokens.radiusLg,
    this.tintColor,
    this.baseColor,
    this.enableGradientInDark = true,
    this.showBorder = false,
    this.enableShadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tintColor;
  final Color? baseColor;
  final bool enableGradientInDark;
  final bool showBorder;
  final bool enableShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final defaultBase =
        theme.cardTheme.color ??
        (isDark ? scheme.surfaceContainerHigh : scheme.surface);
    final base = baseColor ?? defaultBase;
    final tint = tintColor ?? scheme.primary;
    final surfaceColor = base;

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
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: shadows,
        gradient: isDark && enableGradientInDark
            ? appCardGradient(tint: tint, base: base)
            : null,
      ),
      child: child,
    );
  }
}
