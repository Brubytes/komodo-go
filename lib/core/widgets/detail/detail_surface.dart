import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';

/// Shared surface styling for detail pages.
///
/// - Light mode: no gradients (tinted solid background).
/// - Dark mode: subtle gradient allowed for depth.
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base =
        baseColor ??
        (isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainer);
    final tint = tintColor ?? scheme.primary;
    final surfaceColor = isDark
        ? base
        : Color.alphaBlend(tint.withValues(alpha: 0.035), base);

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
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint.withValues(alpha: 0.06), base],
              )
            : null,
      ),
      child: child,
    );
  }
}
