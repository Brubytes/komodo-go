import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../deployments/data/models/deployment.dart';
import '../../../deployments/presentation/providers/deployments_provider.dart';
import '../../../servers/data/models/server.dart';
import '../../../servers/presentation/providers/servers_provider.dart';
import '../../../builds/data/models/build.dart';
import '../../../builds/presentation/providers/builds_provider.dart';
import '../../../procedures/data/models/procedure.dart';
import '../../../procedures/presentation/providers/procedures_provider.dart';
import '../../../repos/data/models/repo.dart';
import '../../../repos/presentation/providers/repos_provider.dart';
import '../../../resources/presentation/providers/resources_tab_provider.dart';
import '../../../stacks/data/models/stack.dart';
import '../../../stacks/presentation/providers/stacks_provider.dart';

/// Home dashboard view.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  void _goToResourcesTab(
    WidgetRef ref,
    BuildContext context,
    ResourceType resourceType,
  ) {
    ref.read(resourcesTabProvider.notifier).setIndex(resourceType.index);
    context.go(AppRoutes.resources);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);
    final stacksAsync = ref.watch(stacksProvider);
    final reposAsync = ref.watch(reposProvider);
    final buildsAsync = ref.watch(buildsProvider);
    final proceduresAsync = ref.watch(proceduresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komodo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to disconnect?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serversProvider);
          ref.invalidate(deploymentsProvider);
          ref.invalidate(stacksProvider);
          ref.invalidate(reposProvider);
          ref.invalidate(buildsProvider);
          ref.invalidate(proceduresProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome message
            Text(
              'Dashboard',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),

            // Quick stats
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Servers',
                  icon: Icons.dns,
                  color: Colors.blue,
                  asyncValue: serversAsync,
                  valueBuilder: (servers) => servers.length.toString(),
                  subtitleBuilder: (servers) {
                    final online = servers
                        .where((s) => s.info?.state == ServerState.ok)
                        .length;
                    return '$online online';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.servers),
                ),
                _StatCard(
                  title: 'Deployments',
                  icon: Icons.rocket_launch,
                  color: Colors.green,
                  asyncValue: deploymentsAsync,
                  valueBuilder: (deployments) => deployments.length.toString(),
                  subtitleBuilder: (deployments) {
                    final running = deployments
                        .where((d) => d.info?.state == DeploymentState.running)
                        .length;
                    return '$running running';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.deployments),
                ),
                _StatCard(
                  title: 'Stacks',
                  icon: Icons.layers,
                  color: Colors.purple,
                  asyncValue: stacksAsync,
                  valueBuilder: (stacks) => stacks.length.toString(),
                  subtitleBuilder: (stacks) {
                    final running = stacks
                        .where((s) => s.info.state == StackState.running)
                        .length;
                    return '$running running';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.stacks),
                ),
                _StatCard(
                  title: 'Repos',
                  icon: Icons.source,
                  color: Colors.orange,
                  asyncValue: reposAsync,
                  valueBuilder: (repos) => repos.length.toString(),
                  subtitleBuilder: (repos) {
                    final busy = repos.where((r) => r.info.state.isBusy).length;
                    return '$busy busy';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.repos),
                ),
                _StatCard(
                  title: 'Builds',
                  icon: Icons.build_circle,
                  color: Colors.teal,
                  asyncValue: buildsAsync,
                  valueBuilder: (builds) => builds.length.toString(),
                  subtitleBuilder: (builds) {
                    final running = builds
                        .where((b) => b.info.state == BuildState.building)
                        .length;
                    return '$running running';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.builds),
                ),
                _StatCard(
                  title: 'Procedures',
                  icon: Icons.playlist_play,
                  color: Colors.indigo,
                  asyncValue: proceduresAsync,
                  valueBuilder: (procedures) => procedures.length.toString(),
                  subtitleBuilder: (procedures) {
                    final running = procedures
                        .where((p) => p.info.state == ProcedureState.running)
                        .length;
                    return '$running running';
                  },
                  onTap: () =>
                      _goToResourcesTab(ref, context, ResourceType.procedures),
                ),
              ],
            ),
            const Gap(24),

            // Recent servers
            _SectionHeader(
              title: 'Servers',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.servers),
            ),
            const Gap(8),
            serversAsync.when(
              data: (servers) {
                if (servers.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.dns_outlined,
                    message: 'No servers',
                  );
                }
                return Column(
                  children: servers
                      .take(3)
                      .map((server) => _ServerListTile(server: server))
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const Gap(24),

            // Recent deployments
            _SectionHeader(
              title: 'Deployments',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.deployments),
            ),
            const Gap(8),
            deploymentsAsync.when(
              data: (deployments) {
                if (deployments.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.rocket_launch_outlined,
                    message: 'No deployments',
                  );
                }
                return Column(
                  children: deployments
                      .take(5)
                      .map(
                        (deployment) =>
                            _DeploymentListTile(deployment: deployment),
                      )
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const Gap(24),

            // Recent stacks
            _SectionHeader(
              title: 'Stacks',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.stacks),
            ),
            const Gap(8),
            stacksAsync.when(
              data: (stacks) {
                if (stacks.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.layers_outlined,
                    message: 'No stacks',
                  );
                }
                return Column(
                  children: stacks
                      .take(5)
                      .map((stack) => _StackListTile(stack: stack))
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const Gap(24),

            // Recent repos
            _SectionHeader(
              title: 'Repos',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.repos),
            ),
            const Gap(8),
            reposAsync.when(
              data: (repos) {
                if (repos.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.source_outlined,
                    message: 'No repos',
                  );
                }
                return Column(
                  children: repos
                      .take(5)
                      .map((repo) => _RepoListTile(repo: repo))
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const Gap(24),

            // Recent builds
            _SectionHeader(
              title: 'Builds',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.builds),
            ),
            const Gap(8),
            buildsAsync.when(
              data: (builds) {
                if (builds.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.build_circle_outlined,
                    message: 'No builds',
                  );
                }
                return Column(
                  children: builds
                      .take(5)
                      .map((build) => _BuildListTile(buildItem: build))
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
            const Gap(24),

            // Recent procedures
            _SectionHeader(
              title: 'Procedures',
              onSeeAll: () =>
                  _goToResourcesTab(ref, context, ResourceType.procedures),
            ),
            const Gap(8),
            proceduresAsync.when(
              data: (procedures) {
                if (procedures.isEmpty) {
                  return const _EmptyListTile(
                    icon: Icons.playlist_play_outlined,
                    message: 'No procedures',
                  );
                }
                return Column(
                  children: procedures
                      .take(5)
                      .map(
                        (procedure) =>
                            _ProcedureListTile(procedure: procedure),
                      )
                      .toList(),
                );
              },
              loading: () => const _LoadingTile(),
              error: (e, _) => _ErrorTile(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard<T> extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.asyncValue,
    required this.valueBuilder,
    required this.subtitleBuilder,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<T>> asyncValue;
  final String Function(List<T>) valueBuilder;
  final String Function(List<T>) subtitleBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const Gap(12),
              asyncValue.when(
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueBuilder(data),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const Gap(4),
                    Text(
                      subtitleBuilder(data),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox(
                  height: 60,
                  child: Center(child: Icon(Icons.error_outline)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

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

class _ServerListTile extends StatelessWidget {
  const _ServerListTile({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    final state = server.info?.state ?? ServerState.unknown;
    final color = switch (state) {
      ServerState.ok => Colors.green,
      ServerState.notOk => Colors.red,
      ServerState.disabled => Colors.grey,
      ServerState.unknown => Colors.orange,
    };

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(server.name),
        subtitle: Text(server.address),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(
          '${AppRoutes.servers}/${server.id}?name=${Uri.encodeComponent(server.name)}',
        ),
      ),
    );
  }
}

class _DeploymentListTile extends StatelessWidget {
  const _DeploymentListTile({required this.deployment});

  final Deployment deployment;

  @override
  Widget build(BuildContext context) {
    final state = deployment.info?.state ?? DeploymentState.unknown;
    final color = switch (state) {
      DeploymentState.deploying => Colors.blue,
      DeploymentState.running => Colors.green,
      DeploymentState.created => Colors.grey,
      DeploymentState.restarting => Colors.blue,
      DeploymentState.removing => Colors.grey,
      DeploymentState.exited => Colors.orange,
      DeploymentState.dead => Colors.red,
      DeploymentState.paused => Colors.grey,
      DeploymentState.notDeployed => Colors.grey,
      DeploymentState.unknown => Colors.orange,
    };

    final imageLabel = deployment.imageLabel;

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(deployment.name),
        subtitle: Text(imageLabel.isNotEmpty ? imageLabel : 'No image'),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _StackListTile extends StatelessWidget {
  const _StackListTile({required this.stack});

  final StackListItem stack;

  @override
  Widget build(BuildContext context) {
    final state = stack.info.state;
    final color = switch (state) {
      StackState.deploying => Colors.blue,
      StackState.running => Colors.green,
      StackState.paused => Colors.grey,
      StackState.stopped => Colors.orange,
      StackState.created => Colors.grey,
      StackState.restarting => Colors.blue,
      StackState.removing => Colors.grey,
      StackState.unhealthy => Colors.red,
      StackState.down => Colors.grey,
      StackState.dead => Colors.red,
      StackState.unknown => Colors.orange,
    };

    final repo = stack.info.repo;
    final branch = stack.info.branch;
    final subtitle = repo.isNotEmpty
        ? (branch.isNotEmpty ? '$repo · $branch' : repo)
        : 'No repo';

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(stack.name),
        subtitle: Text(subtitle),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.stacks}/${stack.id}?name=${Uri.encodeComponent(stack.name)}',
        ),
      ),
    );
  }
}

class _RepoListTile extends StatelessWidget {
  const _RepoListTile({required this.repo});

  final RepoListItem repo;

  @override
  Widget build(BuildContext context) {
    final state = repo.info.state;
    final color = switch (state) {
      RepoState.ok => Colors.green,
      RepoState.failed => Colors.red,
      RepoState.cloning => Colors.blue,
      RepoState.pulling => Colors.blue,
      RepoState.building => Colors.orange,
      RepoState.unknown => Colors.orange,
    };

    final repoPath = repo.info.repo;
    final branch = repo.info.branch;
    final subtitle = repoPath.isNotEmpty
        ? (branch.isNotEmpty ? '$repoPath · $branch' : repoPath)
        : 'No repo';

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(repo.name),
        subtitle: Text(subtitle),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.repos}/${repo.id}?name=${Uri.encodeComponent(repo.name)}',
        ),
      ),
    );
  }
}

class _BuildListTile extends StatelessWidget {
  const _BuildListTile({required this.buildItem});

  final BuildListItem buildItem;

  @override
  Widget build(BuildContext context) {
    final state = buildItem.info.state;
    final color = switch (state) {
      BuildState.building => Colors.blue,
      BuildState.ok => Colors.green,
      BuildState.failed => Colors.red,
      BuildState.unknown => Colors.orange,
    };

    final repo = buildItem.info.repo;
    final branch = buildItem.info.branch;
    final versionLabel = buildItem.info.version.label;
    final subtitleParts = <String>[
      if (repo.isNotEmpty) branch.isNotEmpty ? '$repo · $branch' : repo,
      if (versionLabel != '0.0.0') 'v$versionLabel',
    ];

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(buildItem.name),
        subtitle: subtitleParts.isEmpty
            ? const Text('No repo')
            : Text(subtitleParts.join(' · ')),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.builds}/${buildItem.id}?name=${Uri.encodeComponent(buildItem.name)}',
        ),
      ),
    );
  }
}

class _ProcedureListTile extends StatelessWidget {
  const _ProcedureListTile({required this.procedure});

  final ProcedureListItem procedure;

  @override
  Widget build(BuildContext context) {
    final state = procedure.info.state;
    final color = switch (state) {
      ProcedureState.running => Colors.blue,
      ProcedureState.ok => Colors.green,
      ProcedureState.failed => Colors.red,
      ProcedureState.unknown => Colors.orange,
    };

    final stages = procedure.info.stages;

    return Card(
      child: ListTile(
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(procedure.name),
        subtitle: Text('$stages stages'),
        trailing: Text(
          state.displayName,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () => context.go(
          '${AppRoutes.procedures}/${procedure.id}?name=${Uri.encodeComponent(procedure.name)}',
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const Gap(8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyListTile extends StatelessWidget {
  const _EmptyListTile({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
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
