import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';
import 'package:komodo_go/shared/resources/providers/resources_target_provider.dart';

class ResourcesView extends ConsumerWidget {
  const ResourcesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ResourceType?>(resourcesTargetProvider, (previous, next) {
      if (next == null) return;
      ref.read(resourcesTargetProvider.notifier).clear();
      unawaited(context.push(_routeFor(next)));
    });

    final serversAsync = ref.watch(serversProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final stacksAsync = ref.watch(stacksProvider);
    final reposAsync = ref.watch(reposProvider);
    final syncsAsync = ref.watch(syncsProvider);
    final buildsAsync = ref.watch(buildsProvider);
    final proceduresAsync = ref.watch(proceduresProvider);
    final actionsAsync = ref.watch(actionsProvider);

    _ResourceTile<T> tile<T>({
      required String keyName,
      required String title,
      required IconData icon,
      required Color color,
      required AsyncValue<List<T>> async,
      required bool Function(T item) isFailing,
      required ResourceType type,
      String failingLabel = 'failing',
    }) {
      return _ResourceTile<T>(
        key: ValueKey('resources_stat_$keyName'),
        title: title,
        icon: icon,
        color: color,
        asyncValue: async,
        isFailing: isFailing,
        failingLabel: failingLabel,
        onTap: () => context.push(_routeFor(type)),
      );
    }

    final runTiles = <Widget>[
      tile<Server>(
        keyName: 'servers',
        title: 'Servers',
        icon: AppIcons.server,
        color: AppTokens.resourceServers,
        async: serversAsync,
        isFailing: (s) => s.state == ServerState.notOk,
        failingLabel: 'unreachable',
        type: ResourceType.servers,
      ),
      tile<StackListItem>(
        keyName: 'stacks',
        title: 'Stacks',
        icon: AppIcons.stacks,
        color: AppTokens.resourceStacks,
        async: stacksAsync,
        isFailing: (s) =>
            s.info.state == StackState.unhealthy ||
            s.info.state == StackState.dead,
        failingLabel: 'unhealthy',
        type: ResourceType.stacks,
      ),
      tile<Deployment>(
        keyName: 'deployments',
        title: 'Deployments',
        icon: AppIcons.deployments,
        color: AppTokens.resourceDeployments,
        async: deploymentsAsync,
        isFailing: (d) => d.info?.state == DeploymentState.dead,
        failingLabel: 'unhealthy',
        type: ResourceType.deployments,
      ),
    ];
    final buildTiles = <Widget>[
      tile<BuildListItem>(
        keyName: 'builds',
        title: 'Builds',
        icon: AppIcons.builds,
        color: AppTokens.resourceBuilds,
        async: buildsAsync,
        isFailing: (b) => b.info.state == BuildState.failed,
        failingLabel: 'failed',
        type: ResourceType.builds,
      ),
      tile<RepoListItem>(
        keyName: 'repos',
        title: 'Repos',
        icon: AppIcons.repos,
        color: AppTokens.resourceRepos,
        async: reposAsync,
        isFailing: (r) => r.info.state == RepoState.failed,
        failingLabel: 'failed',
        type: ResourceType.repos,
      ),
      tile<ResourceSyncListItem>(
        keyName: 'syncs',
        title: 'Syncs',
        icon: AppIcons.syncs,
        color: AppTokens.resourceSyncs,
        async: syncsAsync,
        isFailing: (s) => s.info.state == ResourceSyncState.failed,
        failingLabel: 'failed',
        type: ResourceType.syncs,
      ),
      tile<ProcedureListItem>(
        keyName: 'procedures',
        title: 'Procedures',
        icon: AppIcons.procedures,
        color: AppTokens.resourceProcedures,
        async: proceduresAsync,
        isFailing: (p) => p.info.state == ProcedureState.failed,
        failingLabel: 'failed',
        type: ResourceType.procedures,
      ),
      tile<ActionListItem>(
        keyName: 'actions',
        title: 'Actions',
        icon: AppIcons.actions,
        color: AppTokens.resourceActions,
        async: actionsAsync,
        isFailing: (a) => a.info.state == ActionState.failed,
        failingLabel: 'failed',
        type: ResourceType.actions,
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 720;
    final quickStatsColumns = switch (width) {
      >= 1200 => 4,
      >= 720 => 3,
      >= 520 => 3,
      _ => 2,
    };
    final quickStatsAspectRatio = switch (width) {
      >= 720 => 1.2,
      >= 520 => 1.55,
      _ => 1.35,
    };
    final gridSpacing = isTablet ? 12.0 : 8.0;
    final listPadding = isTablet
        ? const EdgeInsets.fromLTRB(24, 24, 24, 28)
        : const EdgeInsets.fromLTRB(12, 12, 12, 20);
    final maxGridWidth = width >= 1200 ? 1180.0 : double.infinity;

    var animIndex = 0;
    Widget grid(List<Widget> tiles) => GridView.count(
      crossAxisCount: quickStatsColumns,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      childAspectRatio: quickStatsAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final t in tiles)
          AppFadeSlide(delay: AppMotion.stagger(animIndex++), child: t),
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Run'),
        grid(runTiles),
        const Gap(20),
        const _SectionHeader(title: 'Build & Automate'),
        grid(buildTiles),
        const Gap(20),
        const _SectionHeader(title: 'Configuration'),
        const _ConfigurationCard(),
      ],
    );

    return Scaffold(
      appBar: const MainAppBar(title: 'Resources', icon: AppIcons.resources),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(serversProvider)
            ..invalidate(deploymentsProvider)
            ..invalidate(stacksProvider)
            ..invalidate(reposProvider)
            ..invalidate(syncsProvider)
            ..invalidate(buildsProvider)
            ..invalidate(proceduresProvider)
            ..invalidate(actionsProvider);
        },
        child: ListView(
          padding: listPadding,
          children: [
            if (maxGridWidth.isFinite)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxGridWidth),
                  child: content,
                ),
              )
            else
              content,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Resource tile: count, title and a "N failing" / "All healthy" subtitle.
class _ResourceTile<T> extends StatelessWidget {
  const _ResourceTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.asyncValue,
    required this.isFailing,
    required this.failingLabel,
    required this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<T>> asyncValue;
  final bool Function(T item) isFailing;
  final String failingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppTokens.radiusLg);

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const Spacer(),
                    Icon(
                      AppIcons.chevron,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ],
                ),
                asyncValue.when(
                  data: (items) {
                    final failing = items.where(isFailing).length;
                    final String subtitle;
                    if (failing > 0) {
                      subtitle = '$failing $failingLabel';
                    } else if (items.isEmpty) {
                      subtitle = 'None yet';
                    } else {
                      subtitle = 'All healthy';
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              items.length.toString(),
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: failing > 0
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: AppInlineSkeleton(size: 20)),
                  ),
                  error: (_, _) => const SizedBox(
                    height: 48,
                    child: Center(child: Icon(AppIcons.formError)),
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

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard();

  @override
  Widget build(BuildContext context) {
    final rows = <(Key, IconData, String, String)>[
      (
        const ValueKey('resources_config_auto_updates'),
        Icons.system_update_alt,
        'Auto-update review',
        AppRoutes.autoUpdateReview,
      ),
      (
        const ValueKey('resources_config_variables'),
        AppIcons.key,
        'Variables',
        AppRoutes.komodoVariables,
      ),
      (
        const ValueKey('resources_config_tags'),
        AppIcons.tag,
        'Tags',
        AppRoutes.komodoTags,
      ),
      (
        const ValueKey('resources_config_providers'),
        AppIcons.repos,
        'Providers',
        AppRoutes.komodoProviders,
      ),
      (
        const ValueKey('resources_config_builders'),
        AppIcons.factory,
        'Builders',
        AppRoutes.komodoBuilders,
      ),
      (
        const ValueKey('resources_config_alerters'),
        AppIcons.notifications,
        'Alerters',
        AppRoutes.komodoAlerters,
      ),
    ];
    final scheme = Theme.of(context).colorScheme;

    return AppCardSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 56,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ListTile(
              key: rows[i].$1,
              leading: Icon(rows[i].$2, color: scheme.primary, size: 22),
              title: Text(
                rows[i].$3,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              trailing: Icon(
                AppIcons.chevron,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              onTap: () => unawaited(context.push(rows[i].$4)),
            ),
          ],
        ],
      ),
    );
  }
}

String _routeFor(ResourceType resource) => switch (resource) {
  ResourceType.servers => AppRoutes.servers,
  ResourceType.deployments => AppRoutes.deployments,
  ResourceType.stacks => AppRoutes.stacks,
  ResourceType.repos => AppRoutes.repos,
  ResourceType.syncs => AppRoutes.syncs,
  ResourceType.builds => AppRoutes.builds,
  ResourceType.procedures => AppRoutes.procedures,
  ResourceType.actions => AppRoutes.actions,
};
