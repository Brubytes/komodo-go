import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/main_app_bar.dart';
import '../../../actions/data/models/action.dart';
import '../../../actions/presentation/providers/actions_provider.dart';
import '../../../builds/data/models/build.dart';
import '../../../builds/presentation/providers/builds_provider.dart';
import '../../../deployments/data/models/deployment.dart';
import '../../../deployments/presentation/providers/deployments_provider.dart';
import '../../../procedures/data/models/procedure.dart';
import '../../../procedures/presentation/providers/procedures_provider.dart';
import '../../../repos/data/models/repo.dart';
import '../../../repos/presentation/providers/repos_provider.dart';
import '../../../resources/presentation/providers/resources_tab_provider.dart';
import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../../../stacks/data/models/stack.dart';
import '../../../stacks/presentation/providers/stacks_provider.dart';
import '../../../syncs/data/models/sync.dart';
import '../../../syncs/presentation/providers/syncs_provider.dart';
import 'home/home_list_tiles.dart';
import 'home/home_sections.dart';
import 'home/home_stat_card.dart';

/// Home dashboard view.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  void _goToResources(BuildContext context, ResourceType resourceType) {
    final route = switch (resourceType) {
      ResourceType.servers => AppRoutes.servers,
      ResourceType.deployments => AppRoutes.deployments,
      ResourceType.stacks => AppRoutes.stacks,
      ResourceType.repos => AppRoutes.repos,
      ResourceType.syncs => AppRoutes.syncs,
      ResourceType.builds => AppRoutes.builds,
      ResourceType.procedures => AppRoutes.procedures,
      ResourceType.actions => AppRoutes.actions,
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final quickStatsColumns = width >= 720 ? 4 : (width >= 520 ? 3 : 2);
    final quickStatsAspectRatio = switch (quickStatsColumns) {
      4 => 1.85,
      3 => 1.70,
      _ => 1.55,
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
      appBar: const MainAppBar(title: 'Dashboard', icon: AppIcons.home),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serversProvider);
          ref.invalidate(deploymentsProvider);
          ref.invalidate(stacksProvider);
          ref.invalidate(reposProvider);
          ref.invalidate(syncsProvider);
          ref.invalidate(buildsProvider);
          ref.invalidate(proceduresProvider);
          ref.invalidate(actionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            // Quick stats
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
                  onTap: () => _goToResources(context, ResourceType.servers),
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
                  onTap: () =>
                      _goToResources(context, ResourceType.deployments),
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
                  onTap: () => _goToResources(context, ResourceType.stacks),
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
                  onTap: () => _goToResources(context, ResourceType.repos),
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
                  onTap: () => _goToResources(context, ResourceType.syncs),
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
                  onTap: () => _goToResources(context, ResourceType.builds),
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
                  onTap: () => _goToResources(context, ResourceType.procedures),
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
                  onTap: () => _goToResources(context, ResourceType.actions),
                ),
              ],
            ),
            const Gap(16),

            // Recent servers
            HomeSectionHeader(
              title: 'Servers',
              onSeeAll: () => _goToResources(context, ResourceType.servers),
            ),
            const Gap(8),
            serversAsync.when(
              data: (servers) {
                if (servers.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.server,
                    message: 'No servers',
                  );
                }
                return Column(
                  children: servers
                      .take(3)
                      .map((server) => HomeServerListTile(server: server))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent deployments
            HomeSectionHeader(
              title: 'Deployments',
              onSeeAll: () => _goToResources(context, ResourceType.deployments),
            ),
            const Gap(8),
            deploymentsAsync.when(
              data: (deployments) {
                if (deployments.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.deployments,
                    message: 'No deployments',
                  );
                }
                return Column(
                  children: deployments
                      .take(5)
                      .map(
                        (deployment) =>
                            HomeDeploymentListTile(deployment: deployment),
                      )
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent stacks
            HomeSectionHeader(
              title: 'Stacks',
              onSeeAll: () => _goToResources(context, ResourceType.stacks),
            ),
            const Gap(8),
            stacksAsync.when(
              data: (stacks) {
                if (stacks.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.stacks,
                    message: 'No stacks',
                  );
                }
                return Column(
                  children: stacks
                      .take(5)
                      .map((stack) => HomeStackListTile(stack: stack))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent repos
            HomeSectionHeader(
              title: 'Repos',
              onSeeAll: () => _goToResources(context, ResourceType.repos),
            ),
            const Gap(8),
            reposAsync.when(
              data: (repos) {
                if (repos.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.repos,
                    message: 'No repos',
                  );
                }
                return Column(
                  children: repos
                      .take(5)
                      .map((repo) => HomeRepoListTile(repo: repo))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent syncs
            HomeSectionHeader(
              title: 'Syncs',
              onSeeAll: () => _goToResources(context, ResourceType.syncs),
            ),
            const Gap(8),
            syncsAsync.when(
              data: (syncs) {
                if (syncs.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.syncs,
                    message: 'No syncs',
                  );
                }
                return Column(
                  children: syncs
                      .take(5)
                      .map((sync) => HomeSyncListTile(sync: sync))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent builds
            HomeSectionHeader(
              title: 'Builds',
              onSeeAll: () => _goToResources(context, ResourceType.builds),
            ),
            const Gap(8),
            buildsAsync.when(
              data: (builds) {
                if (builds.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.builds,
                    message: 'No builds',
                  );
                }
                return Column(
                  children: builds
                      .take(5)
                      .map((build) => HomeBuildListTile(buildItem: build))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent procedures
            HomeSectionHeader(
              title: 'Procedures',
              onSeeAll: () => _goToResources(context, ResourceType.procedures),
            ),
            const Gap(8),
            proceduresAsync.when(
              data: (procedures) {
                if (procedures.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.procedures,
                    message: 'No procedures',
                  );
                }
                return Column(
                  children: procedures
                      .take(5)
                      .map(
                        (procedure) => HomeProcedureListTile(procedure: procedure),
                      )
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
            const Gap(16),

            // Recent actions
            HomeSectionHeader(
              title: 'Actions',
              onSeeAll: () => _goToResources(context, ResourceType.actions),
            ),
            const Gap(8),
            actionsAsync.when(
              data: (actions) {
                if (actions.isEmpty) {
                  return const HomeEmptyListTile(
                    icon: AppIcons.actions,
                    message: 'No actions',
                  );
                }
                return Column(
                  children: actions
                      .take(5)
                      .map((action) => HomeActionListTile(action: action))
                      .toList(),
                );
              },
              loading: () => const HomeLoadingTile(),
              error: (e, _) => HomeErrorTile(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
