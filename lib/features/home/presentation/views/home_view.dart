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

/// Home dashboard view.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);
    final deploymentsAsync = ref.watch(deploymentsProvider);

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
            Row(
              children: [
                Expanded(
                  child: _StatCard(
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
                    onTap: () => context.go(AppRoutes.servers),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _StatCard(
                    title: 'Deployments',
                    icon: Icons.rocket_launch,
                    color: Colors.green,
                    asyncValue: deploymentsAsync,
                    valueBuilder: (deployments) =>
                        deployments.length.toString(),
                    subtitleBuilder: (deployments) {
                      final running = deployments
                          .where(
                            (d) => d.info?.state == DeploymentState.running,
                          )
                          .length;
                      return '$running running';
                    },
                    onTap: () => context.go(AppRoutes.deployments),
                  ),
                ),
              ],
            ),
            const Gap(24),

            // Recent servers
            _SectionHeader(
              title: 'Servers',
              onSeeAll: () => context.go(AppRoutes.servers),
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
              onSeeAll: () => context.go(AppRoutes.deployments),
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
