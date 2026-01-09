import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum DetailMetricTone { primary, secondary, tertiary, success, neutral, alert }

class DetailMetricTileData {
  const DetailMetricTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;
  final DetailMetricTone tone;
}

class DetailMetricGrid extends StatelessWidget {
  const DetailMetricGrid({required this.items, super.key});

  final List<DetailMetricTileData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) =>
              _DetailMetricTile(item: items[index]),
        );
      },
    );
  }
}

class _DetailMetricTile extends StatelessWidget {
  const _DetailMetricTile({required this.item});

  final DetailMetricTileData item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color accent, Color accentContainer) = switch (item.tone) {
      DetailMetricTone.primary => (scheme.primary, scheme.primaryContainer),
      DetailMetricTone.secondary => (
        scheme.secondary,
        scheme.secondaryContainer,
      ),
      DetailMetricTone.tertiary => (scheme.tertiary, scheme.tertiaryContainer),
      DetailMetricTone.success => (scheme.secondary, scheme.secondaryContainer),
      DetailMetricTone.neutral => (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHigh,
      ),
      DetailMetricTone.alert => (scheme.error, scheme.errorContainer),
    };

    final tileBorder = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.22 : 0.40,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentContainer.withValues(alpha: isDark ? 0.26 : 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: isDark ? 0.55 : 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 18, color: accent),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.progress != null) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: item.progress!.clamp(0, 1),
                minHeight: 6,
                backgroundColor: scheme.onSurfaceVariant.withValues(
                  alpha: 0.10,
                ),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
