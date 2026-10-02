import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/composition/home/home_ops_pulse.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:skeletonizer/skeletonizer.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.onSeeAll, super.key});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

class HomeLoadingTile extends StatelessWidget {
  const HomeLoadingTile({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 18),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Loading status', style: textTheme.titleMedium),
                        const Gap(6),
                        Text('Preparing overview', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text('Loading details', style: textTheme.bodyMedium),
              const Gap(8),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text('Loading')),
                  Chip(label: Text('Loading')),
                  Chip(label: Text('Loading')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeErrorTile extends StatelessWidget {
  const HomeErrorTile({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(AppIcons.formError, color: Colors.red),
            const Gap(8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class HomeEmptyListTile extends StatelessWidget {
  const HomeEmptyListTile({
    required this.icon,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const Gap(8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeMetricCard extends StatelessWidget {
  const HomeMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.color,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = color ?? scheme.primary;

    final cardRadius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Builder(
                  builder: (context) {
                    final parts = value.split('\n');
                    final primaryStyle =
                        (parts.first.length > 14
                                ? textTheme.titleLarge
                                : textTheme.headlineSmall)
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            );
                    final secondaryStyle = textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontSize: 10,
                    );

                    if (parts.length == 1) {
                      return Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: primaryStyle,
                      );
                    }

                    return Text.rich(
                      TextSpan(
                        text: parts.first,
                        style: primaryStyle,
                        children: [
                          TextSpan(
                            text: '\n${parts.skip(1).join(' ')}',
                            style: secondaryStyle,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                const Gap(6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeOpsStatusRow extends StatelessWidget {
  const HomeOpsStatusRow({
    required this.title,
    required this.statuses,
    this.onTap,
    super.key,
  });

  final String title;
  final List<HomeOpsStatusCount> statuses;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final visibleStatuses = statuses
        .where((status) => status.count > 0)
        .toList();
    final total = statuses.fold(0, (sum, status) => sum + status.count);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$total',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null) ...[
                const Gap(4),
                Icon(
                  AppIcons.chevron,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          const Gap(6),
          if (visibleStatuses.isEmpty)
            Text(
              'No resources',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                for (final status in visibleStatuses)
                  _HomeOpsStatusLabel(status: status),
              ],
            ),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}

class _HomeOpsStatusLabel extends StatelessWidget {
  const _HomeOpsStatusLabel({required this.status});

  final HomeOpsStatusCount status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status.tone) {
      HomeOpsTone.healthy => AppTokens.statusGreen,
      HomeOpsTone.active => scheme.primary,
      HomeOpsTone.attention => AppTokens.statusOrange,
      HomeOpsTone.failed => scheme.error,
      HomeOpsTone.unknown => scheme.tertiary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(5),
        Text(
          '${status.count} ${status.label.toLowerCase()}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
