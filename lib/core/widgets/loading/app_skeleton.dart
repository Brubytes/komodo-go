import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    this.padding = const EdgeInsets.all(16),
    this.showChips = true,
    super.key,
  });

  final EdgeInsets padding;
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: AppCardSurface(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: padding,
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
                        Text('Loading', style: textTheme.titleMedium),
                        const Gap(6),
                        Text('Fetching details', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text('Loading data', style: textTheme.bodyMedium),
              if (showChips) ...[
                const Gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    Chip(label: Text('Loading')),
                    Chip(label: Text('Loading')),
                    Chip(label: Text('Loading')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppSkeletonSurface extends StatelessWidget {
  const AppSkeletonSurface({
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: DetailSurface(
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loading details', style: textTheme.titleMedium),
              const Gap(8),
              Text('Please wait', style: textTheme.bodySmall),
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: const [
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

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
    this.itemSpacing = 12,
    super.key,
  });

  final int itemCount;
  final EdgeInsets padding;
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => Gap(itemSpacing),
        itemBuilder: (context, index) => AppCardSurface(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(radius: 18),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loading', style: textTheme.titleSmall),
                      const Gap(6),
                      Text('Fetching info', style: textTheme.bodySmall),
                    ],
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

class AppSkeletonCentered extends StatelessWidget {
  const AppSkeletonCentered({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppSkeletonCard());
  }
}

class AppInlineSkeleton extends StatelessWidget {
  const AppInlineSkeleton({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
