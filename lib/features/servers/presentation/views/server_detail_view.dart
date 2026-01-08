import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/utils/byte_format.dart';

import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';

/// View displaying detailed server information.
class ServerDetailView extends ConsumerStatefulWidget {
  const ServerDetailView({
    required this.serverId,
    required this.serverName,
    super.key,
  });

  final String serverId;
  final String serverName;

  @override
  ConsumerState<ServerDetailView> createState() => _ServerDetailViewState();
}

class _ServerDetailViewState extends ConsumerState<ServerDetailView> {
  Timer? _statsRefreshTimer;
  ProviderSubscription<AsyncValue<SystemStats?>>? _statsSubscription;

  int? _previousRefreshTs;
  double? _previousIngressBytes;
  double? _previousEgressBytes;
  double? _ingressBytesPerSecond;
  double? _egressBytesPerSecond;

  @override
  void initState() {
    super.initState();

    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.invalidate(serverStatsProvider(widget.serverId));
    });

    _statsSubscription = ref.listenManual<AsyncValue<SystemStats?>>(
      serverStatsProvider(widget.serverId),
      (previous, next) {
        final stats = next.asData?.value;
        if (stats == null) return;
        _updateNetworkRates(stats);
      },
    );
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    _statsRefreshTimer = null;
    _statsSubscription?.close();
    _statsSubscription = null;
    super.dispose();
  }

  void _updateNetworkRates(SystemStats stats) {
    final previousRefreshTs = _previousRefreshTs;
    final previousIngressBytes = _previousIngressBytes;
    final previousEgressBytes = _previousEgressBytes;

    _previousRefreshTs = stats.refreshTs;
    _previousIngressBytes = stats.networkIngressBytes;
    _previousEgressBytes = stats.networkEgressBytes;

    if (previousRefreshTs == null ||
        previousIngressBytes == null ||
        previousEgressBytes == null) {
      return;
    }

    final dtSeconds = _deltaSeconds(previousRefreshTs, stats.refreshTs);
    if (dtSeconds <= 0) return;

    final ingressDelta = stats.networkIngressBytes - previousIngressBytes;
    final egressDelta = stats.networkEgressBytes - previousEgressBytes;
    if (ingressDelta < 0 || egressDelta < 0) return;

    final ingressBps = ingressDelta / dtSeconds;
    final egressBps = egressDelta / dtSeconds;

    if (ingressBps == _ingressBytesPerSecond &&
        egressBps == _egressBytesPerSecond) {
      return;
    }

    setState(() {
      _ingressBytesPerSecond = ingressBps;
      _egressBytesPerSecond = egressBps;
    });
  }

  double _deltaSeconds(int previousTs, int currentTs) {
    final prev = _toSeconds(previousTs);
    final curr = _toSeconds(currentTs);
    final delta = curr - prev;
    if (delta <= 0) return 0;
    return delta;
  }

  double _toSeconds(int ts) {
    // Komodo timestamps are i64; detect ms epoch vs seconds epoch heuristically.
    if (ts > 1000000000000) return ts / 1000;
    return ts.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final serverAsync = ref.watch(serverDetailProvider(widget.serverId));
    final statsAsync = ref.watch(serverStatsProvider(widget.serverId));
    final systemInfoAsync = ref.watch(
      serverSystemInformationProvider(widget.serverId),
    );

    final server = serverAsync.asData?.value;
    final stats = statsAsync.asData?.value;
    final systemInformation = systemInfoAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(widget.serverName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(serverDetailProvider(widget.serverId))
            ..invalidate(serverSystemInformationProvider(widget.serverId))
            ..invalidate(serverStatsProvider(widget.serverId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ServerSummaryCard(
              server: server,
              stats: stats,
              systemInformation: systemInformation,
              ingressBytesPerSecond: _ingressBytesPerSecond,
              egressBytesPerSecond: _egressBytesPerSecond,
            ),
            const Gap(16),
            serverAsync.when(
              data: (server) => server != null
                  ? _ServerInfoCard(server: server)
                  : const _MessageCard(message: 'Server not found'),
              loading: () => const _LoadingCard(),
              error: (error, _) => _MessageCard(message: 'Error: $error'),
            ),
            const Gap(16),
            systemInfoAsync.when(
              data: (info) => info != null
                  ? _SystemInfoCard(info: info)
                  : const _MessageCard(message: 'System info unavailable'),
              loading: () => const _LoadingCard(),
              error: (error, _) =>
                  _MessageCard(message: 'System info unavailable: $error'),
            ),
            const Gap(16),
            serverAsync.when(
              data: (server) => server?.config != null
                  ? _ServerConfigCard(config: server!.config!)
                  : const _MessageCard(message: 'No config available'),
              loading: () => const _LoadingCard(),
              error: (error, _) => _MessageCard(message: 'Config: $error'),
            ),
            const Gap(16),
            statsAsync.when(
              data: (stats) => _StatsCard(
                stats: stats,
                ingressBytesPerSecond: _ingressBytesPerSecond,
                egressBytesPerSecond: _egressBytesPerSecond,
              ),
              loading: () => const _LoadingCard(),
              error: (error, _) =>
                  _MessageCard(message: 'Stats unavailable: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSummaryCard extends StatelessWidget {
  const _ServerSummaryCard({
    required this.server,
    required this.stats,
    required this.systemInformation,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
  });

  final Server? server;
  final SystemStats? stats;
  final SystemInformation? systemInformation;
  final double? ingressBytesPerSecond;
  final double? egressBytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final version = server?.info?.version;
    final cores = systemInformation?.coreCount;
    final load = stats?.loadAverage?.one;
    final memUsed = stats?.memUsedGb;
    final memTotal = stats?.memTotalGb;
    final diskUsed = stats?.diskUsedGb;
    final diskTotal = stats?.diskTotalGb;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricChip(
                  icon: AppIcons.ok,
                  label: 'Version',
                  value: (version?.isNotEmpty ?? false) ? version! : '—',
                ),
                _MetricChip(
                  icon: AppIcons.cpu,
                  label: 'Cores',
                  value: cores != null ? cores.toString() : '—',
                ),
                _MetricChip(
                  icon: AppIcons.activity,
                  label: 'Load (1m)',
                  value: load != null ? load.toStringAsFixed(2) : '—',
                ),
                _MetricChip(
                  icon: AppIcons.memory,
                  label: 'Memory',
                  value: memUsed != null && memTotal != null && memTotal > 0
                      ? '${memUsed.toStringAsFixed(1)} / ${memTotal.toStringAsFixed(1)} GB'
                      : '—',
                ),
                _MetricChip(
                  icon: AppIcons.hardDrive,
                  label: 'Disk',
                  value: diskUsed != null && diskTotal != null && diskTotal > 0
                      ? '${diskUsed.toStringAsFixed(1)} / ${diskTotal.toStringAsFixed(1)} GB'
                      : '—',
                ),
                _MetricChip(
                  icon: AppIcons.wifi,
                  label: 'Net (in/out)',
                  value:
                      ingressBytesPerSecond != null &&
                          egressBytesPerSecond != null
                      ? '${formatBytesPerSecond(ingressBytesPerSecond!)} / ${formatBytesPerSecond(egressBytesPerSecond!)}'
                      : '—',
                ),
              ],
            ),
            if (server?.tags.isNotEmpty ?? false) ...[
              const Gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in server!.tags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.secondaryContainer,
                      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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
              'Server',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Name', value: server.name),
            _InfoRow(label: 'State', value: server.state.name),
            _InfoRow(label: 'Address', value: server.address),
            if (server.info?.externalAddress.isNotEmpty ?? false)
              _InfoRow(label: 'External', value: server.info!.externalAddress),
            if (server.description != null)
              _InfoRow(label: 'Description', value: server.description!),
          ],
        ),
      ),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({required this.info});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            if (info.name?.isNotEmpty ?? false)
              _InfoRow(label: 'Name', value: info.name!),
            if (info.hostName?.isNotEmpty ?? false)
              _InfoRow(label: 'Host', value: info.hostName!),
            if (info.os?.isNotEmpty ?? false)
              _InfoRow(label: 'OS', value: info.os!),
            if (info.kernel?.isNotEmpty ?? false)
              _InfoRow(label: 'Kernel', value: info.kernel!),
            if (info.cpuBrand.isNotEmpty)
              _InfoRow(label: 'CPU', value: info.cpuBrand),
            if (info.coreCount != null)
              _InfoRow(label: 'Cores', value: info.coreCount.toString()),
            _InfoRow(
              label: 'Terminal',
              value: info.terminalsDisabled ? 'Disabled' : 'Enabled',
            ),
            _InfoRow(
              label: 'Container exec',
              value: info.containerExecDisabled ? 'Disabled' : 'Enabled',
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerConfigCard extends StatelessWidget {
  const _ServerConfigCard({required this.config});

  final ServerConfig config;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Config',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _InfoRow(label: 'Enabled', value: config.enabled ? 'Yes' : 'No'),
            _InfoRow(
              label: 'Region',
              value: config.region.isNotEmpty ? config.region : '—',
            ),
            _InfoRow(
              label: 'Address',
              value: config.address.isNotEmpty ? config.address : '—',
            ),
            _InfoRow(
              label: 'External',
              value: config.externalAddress.isNotEmpty
                  ? config.externalAddress
                  : '—',
            ),
            _InfoRow(
              label: 'Timeout',
              value: config.timeoutSeconds > 0
                  ? '${config.timeoutSeconds}s'
                  : '—',
            ),
            _InfoRow(
              label: 'Passkey',
              value: config.passkey.isNotEmpty ? 'Set' : 'Not set',
            ),
            _InfoRow(
              label: 'Stats monitoring',
              value: config.statsMonitoring ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Auto prune',
              value: config.autoPrune ? 'On' : 'Off',
            ),
            if (config.ignoreMounts.isNotEmpty)
              _InfoRow(
                label: 'Ignore mounts',
                value: config.ignoreMounts.join(', '),
              ),
            if (config.links.isNotEmpty)
              _InfoRow(label: 'Links', value: config.links.join('\n')),
            const Gap(8),
            Text(
              'Alerts & thresholds',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            _InfoRow(
              label: 'Unreachable',
              value: config.sendUnreachableAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'CPU alerts',
              value: config.sendCpuAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Mem alerts',
              value: config.sendMemAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Disk alerts',
              value: config.sendDiskAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'Version mismatch',
              value: config.sendVersionMismatchAlerts ? 'On' : 'Off',
            ),
            _InfoRow(
              label: 'CPU warn/crit',
              value:
                  '${config.cpuWarning.toStringAsFixed(0)}% / ${config.cpuCritical.toStringAsFixed(0)}%',
            ),
            _InfoRow(
              label: 'Mem warn/crit',
              value:
                  '${config.memWarning.toStringAsFixed(1)} GB / ${config.memCritical.toStringAsFixed(1)} GB',
            ),
            _InfoRow(
              label: 'Disk warn/crit',
              value:
                  '${config.diskWarning.toStringAsFixed(1)} GB / ${config.diskCritical.toStringAsFixed(1)} GB',
            ),
            if (config.maintenanceWindows.isNotEmpty) ...[
              const Gap(8),
              Text(
                'Maintenance windows',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(8),
              for (final window in config.maintenanceWindows)
                _InfoRow(
                  label: window.enabled ? 'Enabled' : 'Disabled',
                  value:
                      '${window.name} • ${window.scheduleType.name} • ${window.hour.toString().padLeft(2, '0')}:${window.minute.toString().padLeft(2, '0')} (${window.timezone})',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.stats,
    required this.ingressBytesPerSecond,
    required this.egressBytesPerSecond,
  });

  final SystemStats? stats;
  final double? ingressBytesPerSecond;
  final double? egressBytesPerSecond;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    if (stats == null) {
      return const _MessageCard(message: 'No stats available');
    }

    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            _StatBar(
              label: 'CPU',
              value: stats.cpuPercent,
              color: scheme.primary,
              subtitle: stats.loadAverage != null
                  ? 'Load: ${stats.loadAverage!.one.toStringAsFixed(2)} / ${stats.loadAverage!.five.toStringAsFixed(2)} / ${stats.loadAverage!.fifteen.toStringAsFixed(2)}'
                  : null,
            ),
            const Gap(12),
            _StatBar(
              label: 'Memory',
              value: stats.memPercent,
              subtitle:
                  '${stats.memUsedGb.toStringAsFixed(1)} / ${stats.memTotalGb.toStringAsFixed(1)} GB',
              color: scheme.secondary,
            ),
            const Gap(12),
            _StatBar(
              label: 'Disk',
              value: stats.diskPercent,
              subtitle:
                  '${stats.diskUsedGb.toStringAsFixed(1)} / ${stats.diskTotalGb.toStringAsFixed(1)} GB',
              color: scheme.tertiary,
            ),
            if (stats.disks.isNotEmpty) ...[
              const Gap(12),
              Text(
                'Disks',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(8),
              for (final disk in stats.disks)
                _InfoRow(
                  label: disk.mount.isNotEmpty ? disk.mount : disk.fileSystem,
                  value:
                      '${disk.usedGb.toStringAsFixed(1)} / ${disk.totalGb.toStringAsFixed(1)} GB',
                ),
            ],
            const Gap(12),
            Text(
              'Network',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Gap(8),
            _InfoRow(
              label: 'Ingress',
              value:
                  '${formatBytes(stats.networkIngressBytes)}${ingressBytesPerSecond != null ? ' • ${formatBytesPerSecond(ingressBytesPerSecond!)}' : ''}',
            ),
            _InfoRow(
              label: 'Egress',
              value:
                  '${formatBytes(stats.networkEgressBytes)}${egressBytesPerSecond != null ? ' • ${formatBytesPerSecond(egressBytesPerSecond!)}' : ''}',
            ),
            if (stats.pollingRate?.isNotEmpty ?? false)
              _InfoRow(label: 'Polling', value: stats.pollingRate!),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
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
            width: 120,
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
              '${value.clamp(0, 100).toStringAsFixed(1)}%',
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
            value: (value / 100).clamp(0, 1),
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
