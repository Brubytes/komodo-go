import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/actions/data/models/action.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/builds/data/models/build.dart';
import 'package:komodo_go/features/builds/presentation/providers/builds_provider.dart';
import 'package:komodo_go/features/deployments/data/models/deployment.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/home/presentation/views/home/home_stat_card.dart';
import 'package:komodo_go/features/procedures/data/models/procedure.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/repos/presentation/providers/repos_provider.dart';
import 'package:komodo_go/features/resources/presentation/providers/resources_tab_provider.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/features/syncs/data/models/sync.dart';
import 'package:komodo_go/features/syncs/presentation/providers/syncs_provider.dart';

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
    final tiles = <Widget>[
      HomeStatCard(
        key: const ValueKey('resources_stat_servers'),
        title: 'Servers',
        icon: AppIcons.server,
        asyncValue: serversAsync,
        valueBuilder: (servers) => servers.length.toString(),
        subtitleBuilder: (servers) {
          final online = servers
              .where((server) => server.info?.state == ServerState.ok)
              .length;
          return '$online online';
        },
        onTap: () => context.push(_routeFor(ResourceType.servers)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_deployments'),
        title: 'Deployments',
        icon: AppIcons.deployments,
        asyncValue: deploymentsAsync,
        valueBuilder: (deployments) => deployments.length.toString(),
        subtitleBuilder: (deployments) {
          final running = deployments
              .where(
                (deployment) =>
                    deployment.info?.state == DeploymentState.running,
              )
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.deployments)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_stacks'),
        title: 'Stacks',
        icon: AppIcons.stacks,
        asyncValue: stacksAsync,
        valueBuilder: (stacks) => stacks.length.toString(),
        subtitleBuilder: (stacks) {
          final running = stacks
              .where((stack) => stack.info.state == StackState.running)
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.stacks)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_repos'),
        title: 'Repos',
        icon: AppIcons.repos,
        asyncValue: reposAsync,
        valueBuilder: (repos) => repos.length.toString(),
        subtitleBuilder: (repos) {
          final busy = repos.where((repo) => repo.info.state.isBusy).length;
          return '$busy busy';
        },
        onTap: () => context.push(_routeFor(ResourceType.repos)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_syncs'),
        title: 'Syncs',
        icon: AppIcons.syncs,
        asyncValue: syncsAsync,
        valueBuilder: (syncs) => syncs.length.toString(),
        subtitleBuilder: (syncs) {
          final running = syncs
              .where((sync) => sync.info.state.isRunning)
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.syncs)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_builds'),
        title: 'Builds',
        icon: AppIcons.builds,
        asyncValue: buildsAsync,
        valueBuilder: (builds) => builds.length.toString(),
        subtitleBuilder: (builds) {
          final running = builds
              .where((build) => build.info.state == BuildState.building)
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.builds)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_procedures'),
        title: 'Procedures',
        icon: AppIcons.procedures,
        asyncValue: proceduresAsync,
        valueBuilder: (procedures) => procedures.length.toString(),
        subtitleBuilder: (procedures) {
          final running = procedures
              .where(
                (procedure) => procedure.info.state == ProcedureState.running,
              )
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.procedures)),
      ),
      HomeStatCard(
        key: const ValueKey('resources_stat_actions'),
        title: 'Actions',
        icon: AppIcons.actions,
        asyncValue: actionsAsync,
        valueBuilder: (actions) => actions.length.toString(),
        subtitleBuilder: (actions) {
          final running = actions
              .where((action) => action.info.state == ActionState.running)
              .length;
          return '$running running';
        },
        onTap: () => context.push(_routeFor(ResourceType.actions)),
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 720;
    final quickStatsColumns = switch (width) {
      >= 1200 => 6,
      >= 900 => 5,
      >= 720 => 4,
      >= 520 => 3,
      _ => 2,
    };
    final quickStatsAspectRatio = switch (quickStatsColumns) {
      >= 4 => 1.38,
      3 => 1.55,
      _ => 1.35,
    };
    final gridSpacing = isTablet ? 12.0 : 8.0;
    final listPadding = isTablet
        ? const EdgeInsets.fromLTRB(24, 24, 24, 28)
        : const EdgeInsets.fromLTRB(12, 12, 12, 20);
    final maxGridWidth = switch (width) {
      >= 1200 => 1180.0,
      >= 900 => 1040.0,
      _ => double.infinity,
    };

    final grid = GridView.count(
      crossAxisCount: quickStatsColumns,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      childAspectRatio: quickStatsAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < tiles.length; i++)
          AppFadeSlide(
            delay: AppMotion.stagger(i),
            child: tiles[i],
          ),
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
                  child: grid,
                ),
              )
            else
              grid,
          ],
        ),
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
