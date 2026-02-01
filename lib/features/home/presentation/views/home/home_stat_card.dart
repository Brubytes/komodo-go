import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';

class HomeStatCard<T> extends StatelessWidget {
  const HomeStatCard({
    required this.title,
    required this.icon,
    required this.asyncValue,
    required this.valueBuilder,
    required this.subtitleBuilder,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final AsyncValue<List<T>> asyncValue;
  final String Function(List<T>) valueBuilder;
  final String Function(List<T>) subtitleBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final color = switch (icon) {
      AppIcons.server => AppTokens.resourceServers,
      AppIcons.deployments => AppTokens.resourceDeployments,
      AppIcons.stacks => AppTokens.resourceStacks,
      AppIcons.repos => AppTokens.resourceRepos,
      AppIcons.syncs => AppTokens.resourceSyncs,
      AppIcons.builds => AppTokens.resourceBuilds,
      AppIcons.procedures => AppTokens.resourceProcedures,
      AppIcons.actions => AppTokens.resourceActions,
      _ => scheme.primary,
    };

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // In tests and very compact layouts the grid can become quite short.
              // Keep this threshold generous to avoid overflows.
              final isTight = constraints.maxHeight < 110;
              final padding = isTight ? 6.0 : 14.0;
              final iconSize = isTight ? 14.0 : 22.0;
              final iconPadding = isTight ? 3.0 : 8.0;
              final showSubtitle = !isTight;

              final valueStyle =
                  (isTight ? textTheme.titleMedium : textTheme.headlineMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      );
              final titleStyle =
                  (isTight ? textTheme.titleSmall : textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: -0.1,
                      );
              final subtitleStyle =
                  (isTight ? textTheme.labelMedium : textTheme.labelLarge)
                      ?.copyWith(color: color, fontWeight: FontWeight.w700);

              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(iconPadding),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: iconSize),
                        ),
                        const Spacer(),
                        if (!isTight)
                          Icon(
                            AppIcons.chevron,
                            size: 20,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                      ],
                    ),
                    asyncValue.when(
                      data: (data) {
                        if (isTight) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(valueBuilder(data), style: valueStyle),
                              const Gap(6),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleStyle,
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(valueBuilder(data), style: valueStyle),
                                const Gap(8),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: titleStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (showSubtitle) ...[
                              const Gap(2),
                              Text(
                                subtitleBuilder(data),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => SizedBox(
                        height: isTight ? 32 : 48,
                        child: const Center(child: AppInlineSkeleton(size: 20)),
                      ),
                      error: (_, __) => SizedBox(
                        height: isTight ? 32 : 48,
                        child: const Center(child: Icon(AppIcons.formError)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
