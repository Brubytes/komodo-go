import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

LinearGradient appCardGradient({required Color tint, required Color base}) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tint.withValues(alpha: 0.05), base.withValues(alpha: 0.25)],
  );
}

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
    this.enableGradientInDark = false,
    this.tintColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool showBorder;
  final bool enableShadow;

  /// Optional tap handler. When set, the surface shows ink feedback and a
  /// subtle press scale.
  final VoidCallback? onTap;
  final bool enableGradientInDark;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final color = theme.cardTheme.color ?? scheme.surface;
    final tint = tintColor ?? scheme.primary;

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
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: borderColor) : null,
        boxShadow: shadows,
        gradient: isDark && enableGradientInDark
            ? appCardGradient(tint: tint, base: color)
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
