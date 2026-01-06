import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/models/server.dart';
import '../../data/models/system_stats.dart';
import '../providers/servers_provider.dart';
import '../widgets/server_card.dart';

/// View displaying the list of all servers.
class ServersListView extends ConsumerWidget {
  const ServersListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(serversProvider.notifier).refresh(),
        child: serversAsync.when(
          data: (servers) {
            if (servers.isEmpty) {
              return const _EmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: servers.length,
              separatorBuilder: (context, index) => const Gap(12),
              itemBuilder: (context, index) {
                final server = servers[index];
                return ServerCard(
                  server: server,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ServerDetailView(
                          serverId: server.id,
                          serverName: server.name,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(serversProvider),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No servers found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Add servers in the Komodo web interface',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const Gap(16),
            Text(
              'Failed to load servers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// View displaying detailed server information.
class ServerDetailView extends ConsumerWidget {
  const ServerDetailView({
    required this.serverId,
    required this.serverName,
    super.key,
  });

  final String serverId;
  final String serverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverAsync = ref.watch(serverDetailProvider(serverId));
    final statsAsync = ref.watch(serverStatsProvider(serverId));

    return Scaffold(
      appBar: AppBar(title: Text(serverName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serverDetailProvider(serverId));
          ref.invalidate(serverStatsProvider(serverId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Server Info Card
            serverAsync.when(
              data: (server) => server != null
                  ? _ServerInfoCard(server: server)
                  : const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Server not found'),
                      ),
                    ),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $error'),
                ),
              ),
            ),
            const Gap(16),

            // Stats Card
            statsAsync.when(
              data: (stats) => _StatsCard(stats: stats),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Stats unavailable: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerInfoCard extends StatelessWidget {
  const _ServerInfoCard({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: server.name),
            _InfoRow(label: 'Address', value: server.address),
            if (server.description != null)
              _InfoRow(label: 'Description', value: server.description!),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final SystemStats? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    if (stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No stats available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _StatBar(label: 'CPU', value: stats.cpuPercent, color: Colors.blue),
            const Gap(12),
            _StatBar(
              label: 'Memory',
              value: stats.memPercent,
              subtitle:
                  '${stats.memUsedGb.toStringAsFixed(1)} / ${stats.memTotalGb.toStringAsFixed(1)} GB',
              color: Colors.green,
            ),
            const Gap(12),
            _StatBar(
              label: 'Disk',
              value: stats.diskPercent,
              subtitle:
                  '${stats.diskUsedGb.toStringAsFixed(1)} / ${stats.diskTotalGb.toStringAsFixed(1)} GB',
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String label;
  final double value;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const Gap(4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        if (subtitle != null) ...[
          const Gap(4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}
