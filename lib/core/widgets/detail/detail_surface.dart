import 'package:flutter/material.dart';

/// Shared surface styling for detail pages.
///
/// - Light mode: no gradients (tinted solid background).
/// - Dark mode: subtle gradient allowed for depth.
class DetailSurface extends StatelessWidget {
  const DetailSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.tintColor,
    this.baseColor,
    this.enableGradientInDark = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tintColor;
  final Color? baseColor;
  final bool enableGradientInDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = baseColor ?? scheme.surfaceContainer;
    final tint = tintColor ?? scheme.primary;
    final surfaceColor = isDark
        ? base
        : Color.alphaBlend(tint.withValues(alpha: 0.06), base);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
        gradient: isDark && enableGradientInDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint.withValues(alpha: 0.10), base],
              )
            : null,
      ),
      child: child,
    );
  }
}
