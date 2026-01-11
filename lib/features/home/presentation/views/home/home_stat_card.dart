import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // In tests and very compact layouts the grid can become quite short.
            // Keep this threshold generous to avoid overflows.
            final isTight = constraints.maxHeight < 92;
            final padding = isTight ? 8.0 : 11.0;
            final iconSize = isTight ? 16.0 : 19.0;
            final gap = isTight ? 4.0 : 6.0;
            const showSubtitle = true;

            final valueStyle =
                (isTight ? textTheme.titleLarge : textTheme.headlineSmall)
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    );
            final titleStyle =
                (isTight ? textTheme.titleSmall : textTheme.titleSmall)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                      letterSpacing: -0.1,
                    );
            final subtitleStyle =
                (isTight ? textTheme.labelMedium : textTheme.labelMedium)
                    ?.copyWith(color: color, fontWeight: FontWeight.w700);

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTight ? 4 : 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: iconSize),
                      ),
                      const Spacer(),
                      Icon(
                        AppIcons.chevron,
                        size: isTight ? 18 : 20,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                  Gap(gap),
                  asyncValue.when(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(valueBuilder(data), style: valueStyle),
                            const Gap(8),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: isTight ? 0 : 2,
                                ),
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
                    ),
                    loading: () => SizedBox(
                      height: isTight ? 32 : 40,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => SizedBox(
                      height: isTight ? 32 : 40,
                      child: const Center(child: Icon(AppIcons.formError)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
