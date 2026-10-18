import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
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
    this.enableGradientInDark = false,
    this.showBorder = false,
    this.enableShadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tintColor;
  final Color? baseColor;
  final bool enableGradientInDark;
  final bool showBorder;
  final bool enableShadow;

  /// Optional tap handler. When set, the surface shows ink feedback and a
  /// subtle press scale.
  final VoidCallback? onTap;

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

    // Large blurred shadows are expensive to paint and nearly invisible on
    // dark surfaces, so they are only drawn in light mode.
    final shadows = enableShadow && !isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
              spreadRadius: -8,
            ),
          ]
        : const <BoxShadow>[];

    final tappable = onTap != null;
    final surface = Container(
      padding: tappable ? null : padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: shadows,
        gradient: isDark && enableGradientInDark
            ? appCardGradient(tint: tint, base: base)
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: tappable
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: Padding(padding: padding, child: child),
              )
            : child,
      ),
    );
    return tappable ? AppPressable(child: surface) : surface;
  }
}
