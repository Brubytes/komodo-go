import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'detail_surface.dart';

class DetailSubCard extends StatelessWidget {
  const DetailSubCard({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
    this.tintColor,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = tintColor ?? scheme.primary;

    return DetailSurface(
      radius: 20,
      baseColor: scheme.surfaceContainerHigh,
      tintColor: tint,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const Gap(10),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const Gap(12),
          child,
        ],
      ),
    );
  }
}
