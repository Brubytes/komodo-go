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
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? tintColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = tintColor ?? scheme.primary;

    return DetailSurface(
      tintColor: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const Gap(12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const Gap(14),
          child,
        ],
      ),
    );
  }
}
