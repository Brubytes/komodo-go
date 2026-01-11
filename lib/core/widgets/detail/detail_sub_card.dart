import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

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

    return AppCardSurface(
      radius: 20,
      padding: const EdgeInsets.all(12),
      enableShadow: false,
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
