import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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
import 'package:komodo_go/features/home/presentation/views/home/home_list_tiles.dart';
import 'package:komodo_go/features/home/presentation/views/home/home_sections.dart';
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
