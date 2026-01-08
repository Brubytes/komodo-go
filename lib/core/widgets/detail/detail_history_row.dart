import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class DetailHistoryRow extends StatelessWidget {
  const DetailHistoryRow({
    required this.label,
    required this.value,
    required this.child,
    super.key,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const Gap(6),
        SizedBox(height: 56, width: double.infinity, child: child),
      ],
    );
  }
}
