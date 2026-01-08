import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A compact "label + value" row used in detail pages.
class DetailKeyValueRow extends StatelessWidget {
  const DetailKeyValueRow({
    required this.label,
    required this.value,
    super.key,
    this.labelWidth = 120,
    this.bottomPadding = 8,
  });

  final String label;
  final String value;
  final double labelWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// An icon-backed info row used in detail hero headers.
class DetailIconInfoRow extends StatelessWidget {
  const DetailIconInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.tintColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final tint = tintColor ?? scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
