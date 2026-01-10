import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
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
      context.push(_routeFor(next));
    });

    final width = MediaQuery.sizeOf(context).width;
    final quickStatsColumns = width >= 720 ? 4 : (width >= 520 ? 3 : 2);
    final quickStatsAspectRatio = switch (quickStatsColumns) {
      4 => 1.85,
      3 => 1.65,
      _ => 1.35,
    };

    final serversAsync = ref.watch(serversProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final stacksAsync = ref.watch(stacksProvider);
    final reposAsync = ref.watch(reposProvider);
    final syncsAsync = ref.watch(syncsProvider);
    final buildsAsync = ref.watch(buildsProvider);
    final proceduresAsync = ref.watch(proceduresProvider);
    final actionsAsync = ref.watch(actionsProvider);

    return Scaffold(
      appBar: const MainAppBar(title: 'Resources', icon: AppIcons.resources),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          GridView.count(
            crossAxisCount: quickStatsColumns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: quickStatsAspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              HomeStatCard(
                title: 'Servers',
                icon: AppIcons.server,
                asyncValue: serversAsync,
                valueBuilder: (servers) => servers.length.toString(),
                subtitleBuilder: (servers) {
                  final online = servers
                      .where((s) => s.info?.state == ServerState.ok)
                      .length;
                  return '$online online';
                },
                onTap: () => context.push(_routeFor(ResourceType.servers)),
              ),
              HomeStatCard(
                title: 'Deployments',
                icon: AppIcons.deployments,
                asyncValue: deploymentsAsync,
                valueBuilder: (deployments) => deployments.length.toString(),
                subtitleBuilder: (deployments) {
                  final running = deployments
                      .where((d) => d.info?.state == DeploymentState.running)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.deployments)),
              ),
              HomeStatCard(
                title: 'Stacks',
                icon: AppIcons.stacks,
                asyncValue: stacksAsync,
                valueBuilder: (stacks) => stacks.length.toString(),
                subtitleBuilder: (stacks) {
                  final running = stacks
                      .where((s) => s.info.state == StackState.running)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.stacks)),
              ),
              HomeStatCard(
                title: 'Repos',
                icon: AppIcons.repos,
                asyncValue: reposAsync,
                valueBuilder: (repos) => repos.length.toString(),
                subtitleBuilder: (repos) {
                  final busy = repos.where((r) => r.info.state.isBusy).length;
                  return '$busy busy';
                },
                onTap: () => context.push(_routeFor(ResourceType.repos)),
              ),
              HomeStatCard(
                title: 'Syncs',
                icon: AppIcons.syncs,
                asyncValue: syncsAsync,
                valueBuilder: (syncs) => syncs.length.toString(),
                subtitleBuilder: (syncs) {
                  final running = syncs
                      .where((s) => s.info.state.isRunning)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.syncs)),
              ),
              HomeStatCard(
                title: 'Builds',
                icon: AppIcons.builds,
                asyncValue: buildsAsync,
                valueBuilder: (builds) => builds.length.toString(),
                subtitleBuilder: (builds) {
                  final running = builds
                      .where((b) => b.info.state == BuildState.building)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.builds)),
              ),
              HomeStatCard(
                title: 'Procedures',
                icon: AppIcons.procedures,
                asyncValue: proceduresAsync,
                valueBuilder: (procedures) => procedures.length.toString(),
                subtitleBuilder: (procedures) {
                  final running = procedures
                      .where((p) => p.info.state == ProcedureState.running)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.procedures)),
              ),
              HomeStatCard(
                title: 'Actions',
                icon: AppIcons.actions,
                asyncValue: actionsAsync,
                valueBuilder: (actions) => actions.length.toString(),
                subtitleBuilder: (actions) {
                  final running = actions
                      .where((a) => a.info.state == ActionState.running)
                      .length;
                  return '$running running';
                },
                onTap: () => context.push(_routeFor(ResourceType.actions)),
              ),
            ],
          ),
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
