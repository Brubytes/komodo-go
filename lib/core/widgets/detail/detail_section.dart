import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/widgets/detail/detail_surface.dart';

class DetailSection extends StatelessWidget {
  const DetailSection({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
    this.tintColor,
    this.trailing,
    this.baseColor,
    this.showBorder = false,
    this.enableShadow = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? tintColor;
  final Widget? trailing;
  final Color? baseColor;
  final bool showBorder;
  final bool enableShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = tintColor ?? scheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? scheme.onPrimary : scheme.onSurface;
    // Make base color transparent if not provided 
    final baseColor = this.baseColor ?? scheme.surface.withValues(alpha: 0);

    return DetailSurface(
      tintColor: tint,
      baseColor: baseColor,
      showBorder: showBorder,
      enableShadow: enableShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: titleColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: titleColor),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Gap(16),
          child,
        ],
      ),
    );
  }
}
